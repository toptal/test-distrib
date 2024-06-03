require 'drb'

module DistribCore
  # Helper that handles some problematic cases with DRb.
  module DRbHelper
    class << self
      # Checks if any of the passed object is a `DRbUnknown`.
      # It tries to load such objects and logs explained error if fails.
      # Used on Leader when receiving report from workers.
      #
      # @param objects [Array<Object>]
      # @return [TrueClass, FalseClass] `true` if failed to load one of the passed objects
      def drb_unknown?(*objects)
        got_drb_unknown = false

        objects.each do |object|
          next unless object.is_a?(DRb::DRbUnknown)

          error = error_of_marshal_load(object)

          logger.error 'Parse error:'
          logger.error error
          logger.debug "Can't parse: #{object.inspect}"

          got_drb_unknown = true
        end

        got_drb_unknown
      end

      # Checks if error was caused by `Marshal#dump`.
      # Recursively explores object and tries to `Marshal.dump` it.
      # If dump failed - calls the same function for its instance variables.
      # Logs path to the un-dumpable object.
      # Used on Worker to find objects(or parts) which can't be sent to Leader.
      #
      # @param error [Exception]
      # @param objects [Object]
      # @return [TrueClass, FalseClass]
      def dump_failed?(error, objects)
        return false unless marshal_error?(error)

        dig_dump(objects)
        true
      end

      private

      # Checks if error was caused by `Marshal#dump`.
      #
      # @param error [Exception]
      # @return [Boolean]
      def marshal_error?(error)
        while error
          if error.is_a?(TypeError) && error.message.include?('no _dump_data is defined for')
            logger.error 'Marshal dump error:'
            logger.error error
            return true
          end

          error = error.cause
        end
        false
      end

      # Recursively explores object and tries to `Marshal.dump` it.
      # If dump failed - calls the same function for its instance variables.
      # Logs path to the un-dumpable object.
      # Used on Worker to find objects(or parts) which can't be sent to Leader.
      #
      # @param obj [Object] object to explore
      # @param parent_objects [Array<Object>] list of parent objects we already digging in
      # @param vars [Array<Symbol>] list of instance variables we already digging in
      def dig_dump(obj, parent_objects = [], vars = []) # rubocop:disable Metrics/
        objs = if obj.is_a?(Array)
                 obj.flatten
               elsif obj.is_a?(Hash)
                 obj.to_a.flatten
               else
                 [obj]
               end

        objs.each do |o|
          Marshal.dump(o)
        rescue TypeError
          if o.instance_variables.none?
            path = [parent_objects, vars].transpose.map(&:join).join(' ')
            logger.debug "Cant serialize #{o} in path #{path}"
          else
            o.instance_variables.each do |var|
              val = o.instance_variable_get(var)
              next unless val

              dig_dump(val, parent_objects + [o.class], vars + [var])
            end
          end
        end

        nil
      end

      def error_of_marshal_load(object)
        error = nil

        begin
          Marshal.load(object.buf) # rubocop:disable Security/MarshalLoad
        rescue StandardError => e
          error = e
        end

        error
      end

      def logger
        DistribCore.configuration.broadcaster
      end
    end
  end
end

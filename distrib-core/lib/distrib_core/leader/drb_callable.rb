require 'distrib_core/drb_helper'

module DistribCore
  module Leader
    # A wrapper for methods available through DRb.
    # Use this module to wrap DRb exposed methods to handle and log any error.
    module DRbCallable
      # Wraps the method. If it raises exception - logs it and calls `handle_non_example_exception`
      #
      # @example
      #     drb_callable def ping
      #       puts 'pong'
      #     end
      #
      # @param method_name [Symbol]
      # @return NilClass
      def drb_callable(method_name) # rubocop:disable Metrics/MethodLength:
        alias_method "drb_callable_#{method_name}", method_name

        define_method method_name do |*args| # rubocop:disable Metrics/MethodLength:
          if DistribCore::DRbHelper.drb_unknown?(*args)
            handle_non_example_exception
            nil
          else
            public_send("drb_callable_#{method_name}", *args)
          end
        rescue StandardError => e
          logger.error "Failed to call #{method_name}"
          logger.error e
          handle_non_example_exception
          nil
        end
      end
    end
  end
end

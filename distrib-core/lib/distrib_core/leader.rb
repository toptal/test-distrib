require 'distrib_core/leader/drb_callable'
require 'distrib_core/leader/queue_builder'
require 'distrib_core/leader/queue_with_lease'
require 'distrib_core/leader/watchdog'

module DistribCore
  # Stores common methods for Leader (basic module for Leader).
  module Leader
    # @param klass [Class]
    def self.included(klass)
      klass.extend(ClassMethods)
      klass.extend(DRbCallable)
    end

    private

    # Methods to define on class-level
    module ClassMethods
      private

      def logger
        DistribCore.configuration.broadcaster
      end
    end

    def logger
      DistribCore.configuration.broadcaster
    end
  end
end

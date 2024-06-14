require 'delegate'

module RSpec
  module Distrib
    module Worker
      # @api private
      # Custom reporter to notify leader about non_example_exception.
      class LeaderReporter < SimpleDelegator
        # @param leader [DRbObject(RSpec::Distrib::Leader)]
        def initialize(leader, *)
          super(*)
          @leader = leader
        end

        # Calls original behaviour and notifies leader.
        # @param exception [Exception]
        def notify_non_example_exception(exception, context_description)
          super

          return if force_exit_signal?

          converted_exception = RSpec::Distrib::ExecutionResults::Exception.new(exception)
          @leader.notify_non_example_exception(converted_exception, context_description)
        end

        private

        def force_exit_signal?
          DistribCore::ReceivedSignals.received?('TERM') ||
            DistribCore::ReceivedSignals.force_int?
        end
      end
    end
  end
end

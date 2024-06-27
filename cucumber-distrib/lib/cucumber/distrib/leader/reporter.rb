module Cucumber
  module Distrib
    class Leader
      # Reporter instance used by Leader to notify reporters.
      # Uses Mutex to prevent race conditions.
      class Reporter
        # @param runtime [Cucumber::Runtime]
        def initialize(runtime)
          @runtime = runtime
          # Reporters might fail because of race condition.
          @mutex = Mutex.new
        end

        # Send :test_run_started notification.
        def report_test_run_started
          mutex.synchronize do
            runtime.configuration.notify :test_run_started, []
          end
        end

        # Fire events from workers on Leader for reporters.
        #
        # @param events [Array<Cucumber::Distrib::Events::Event>]
        def report_events(events)
          mutex.synchronize do
            events.each do |e|
              runtime.configuration.event_bus.broadcast(e)
            end
          end
        end

        # Send :retrying_test notification.
        #
        # @param test_case_event [Cucumber::Distrib::Events::TestCaseFinished]
        def report_retrying_test(test_case_event)
          return unless test_case_event

          mutex.synchronize do
            runtime.configuration.notify(:retrying_test, test_case_event)
          end
        end

        # Send :test_run_finished notification.
        def report_test_run_finished
          mutex.synchronize do
            runtime.configuration.notify :test_run_finished
          end
        end

        private

        attr_reader :runtime, :mutex
      end
    end
  end
end

require 'rainbow/refinement'

module DistribCore
  module Leader
    # A watchdog to observe the state of queue.
    # A thread running on the background that keeps checking if there are tests to run.
    # It closes the connection between Leader and Workers when the queues are empty.
    # A thread watching over presence of the entries on the queue and lease
    # timeouts. Stops the {Leader} by stopping its DRb exposed service.
    class Watchdog # rubocop:disable Metrics/ClassLength
      using Rainbow

      def initialize(queue)
        @queue = queue
        @failed = false
        @logger = DistribCore.configuration.broadcaster
      end

      def start # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        Thread.new do
          loop do
            if ::DistribCore::ReceivedSignals.any?
              logger.warn ::DistribCore::ReceivedSignals.message
              DRb.current_server.stop_service
              break
            end

            handle_timed_out_tests

            if queue.empty? # no more tests left
              logger.info 'Queue is empty. Stopping.'
              DRb.current_server.stop_service
              break
            end

            timeout_error = handle_workers_timeout

            if timeout_error
              logger.error timeout_error
              logger.info not_executed_tests_after_timeout_report
              @failed = true
              DRb.current_server.stop_service
              break
            end

            Kernel.sleep(1)
          end
        end
      end

      # @return [TrueClass, FalseClass] `true` when watchdog encountered an error
      def failed?
        @failed
      end

      private

      attr_reader :queue, :logger

      def config
        DistribCore.configuration
      end

      def timed_out_tests
        queue.select_leased do |test, start_time|
          start_time < Time.now - config.timeout_for(test)
        end.keys
      end

      def repush(test)
        queue.repush(test)
        Metrics.watchdog_repushed(test, config.timeout_for(test))
      end

      def handle_timed_out_tests
        timed_out_tests.each do |test|
          timeout = config.timeout_for(test)
          logger.warn "#{test} (Timeout: #{formatted_timeout(timeout)}) #{strategy_warn}"

          release_on_timeout? ? queue.release(test) : repush(test)
        end
      end

      def release_on_timeout?
        config.timeout_strategy == :release
      end

      def strategy_warn
        return 'will NOT be pushed back to the queue - marking as completed.' if release_on_timeout?

        'but will be pushed back to the queue.'
      end

      def not_executed_tests_after_timeout_report
        tests = queue.entries_list
        tests_to_show = [tests.length, 10].min

        <<~TEXT
          #{tests.length} tests not executed, showing #{tests_to_show}:
          #{tests.take(tests_to_show).join("\n")}
        TEXT
      end

      def handle_workers_timeout
        if queue.visited?
          tests_picked_timeout_error
        else
          workers_failed_to_start_error
        end
      end

      def tests_picked_timeout_error
        return unless (Time.now - queue.last_activity_at) > config.tests_processing_stopped_timeout

        <<~ERROR_MESSAGE.strip
          Workers did not pick tests for too long!
          After Workers processed #{queue.completed_size} test(s), Leader will abort as it waited for over
          #{formatted_timeout(config.tests_processing_stopped_timeout)} which is the configured time to wait for
          Workers to pick up tests.
          Aborting...
        ERROR_MESSAGE
      end

      def workers_failed_to_start_error
        return if queue.leased_size.nonzero?

        return unless (Time.now - queue.initialized_at) > config.first_test_picked_timeout

        <<~ERROR_MESSAGE.strip
          Leader has reached the time limit of #{formatted_timeout(config.first_test_picked_timeout)} for the first test being picked from the queue.
          This probably means that all workers have failed to be initialized or took too long to start.
          Leader will now abort.
          Aborting...
        ERROR_MESSAGE
      end

      def formatted_timeout(time)
        minutes = time.to_i / 60
        seconds = time.to_i % 60

        formatted_text = []
        formatted_text << "#{minutes} minute(s)" if minutes.positive?
        formatted_text << "#{seconds} second(s)" if seconds.positive?

        formatted_text.join(' ')
      end
    end
  end
end

module DistribCore
  # Collect metrics from Leader and Workers.
  module Metrics
    class << self
      # Stores metrics
      def report
        @report ||= {
          queue_exposed_at: nil,
          first_test_taken_at: nil,
          watchdog_repush_count: 0,
          repushed_files: Hash.new { |h, k| h[k] = [] }
        }
      end

      # Records Leader is ready to serve tests
      def queue_exposed
        report[:queue_exposed_at] = Time.now.to_i
      end

      # Records first test was taken by a worker
      def test_taken
        report[:first_test_taken_at] ||= Time.now.to_i
      end

      # Records when watchdog repushes files back to queue because of timeout
      #
      # @param test [String]
      # @param timeout_in_seconds [Float] timeout which was exceeded
      def watchdog_repushed(test, timeout_in_seconds)
        report[:watchdog_repush_count] += 1
        report[:repushed_files][test] << timeout_in_seconds
      end
    end
  end
end

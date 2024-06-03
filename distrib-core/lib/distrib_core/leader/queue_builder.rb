module DistribCore
  module Leader
    # Helper that builds a list of the test files to execute sorted by average
    # execution time descending. The order strategy is backed by
    # https://en.wikipedia.org/wiki/Queueing_theory
    module QueueBuilder
      # @return [Array<String>] list of test files in the order they should be enqueued
      def self.tests
        ::DistribCore.configuration.tests_provider.call
      end
    end
  end
end

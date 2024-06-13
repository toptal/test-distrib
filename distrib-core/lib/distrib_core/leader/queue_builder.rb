module DistribCore
  module Leader
    # Helper that builds a list of the test files to execute.
    # The order of files is controlled by used tests provider.
    module QueueBuilder
      # @return [Array<String>] list of test files in the order they should be enqueued
      def self.tests
        ::DistribCore.configuration.tests_provider.call
      end
    end
  end
end

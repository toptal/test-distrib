require 'distrib_core/configuration'
require 'cucumber/distrib/leader/tests_provider'
require 'cucumber/distrib/leader/cucumber_helper'

module Cucumber
  module Distrib
    # Configuration holder.
    #
    # @example Get global instance of configuration:
    #     Cucumber::Distrib.configuration
    #
    # @example Override default list of the tests:
    #     Cucumber::Distrib.configure do |config|
    #       config.tests_provider = -> {
    #         Dir.glob(['features/**/*.feature', 'engines/**/*.feature'])
    #       }
    #     end
    #
    # @example Specify which errors should fail leader. Other errors will be retried, here you can specify how many times.
    #     RSpec::Distrib.configure do |config|
    #       config.error_handler.retryable_exceptions = ['Elasticsearch::ServiceUnavailable']
    #       config.error_handler.retry_attempts = 2
    #       config.error_handler.fatal_worker_failures = ['NameError']
    #       config.error_handler.failed_workers_threshold = 2
    #     end
    #
    # @example Or set your own logic to handle errors. It should respond to `#retry_test?`, `#ignore_worker_failure?` methods.
    #     RSpec::Distrib.configure do |config|
    #       config.error_handler = MyErrorHandler
    #     end
    #
    # @example Set equal timeout for all tests to 30 seconds:
    #     Cucumber::Distrib.configure do |config|
    #       config.test_timeout = 30 # seconds
    #     end
    #
    # @example Or you can specify timeout per test. An object that responds to `call` and receives the test as an argument. The proc returns the timeout in seconds.
    #     Cucumber::Distrib.configure do |config|
    #       config.test_timeout = ->(test) do
    #         10 + 2 * average_execution_in_seconds(test)
    #       end
    #     end
    #
    # @example Set how long Leader will wait before first test gets processed by workers. Leader will exit if no tests picked in this period.
    #     Cucumber::Distrib.configure do |config|
    #       config.first_test_picked_timeout = 10*60 # seconds
    #     end
    #
    # @example Specify custom options for DRb service. Defaults are `{ safe_level: 1 }`. @see `DRb::DRbServer.new` for complete list
    #     Cucumber::Distrib.configure do |config|
    #       config.drb = {safe_level: 0, verbose: true}
    #     end
    #
    # @example Specify custom block to pre-process examples before reporting them to Leader. Useful to add additional information about workers.
    #     Cucumber::Distrib.configure do |config|
    #       config.before_test_report = -> (file_name, example_groups) do
    #         example_groups.each { |eg| eg.metadata[:custom] = 'foo' }
    #       end
    #     end
    #
    # @example Specify custom block which will be called on Leader after run.
    #     Cucumber::Distrib.configure do |config|
    #       config.on_finish = -> () do
    #         'Whatever logic before Leader exit'
    #       end
    #     end
    #
    class Configuration
      include ::DistribCore::Configuration

      def initialize
        super
        @tests_provider = ::Cucumber::Distrib::Leader::TestsProvider
        @error_handler = ::DistribCore::Leader::ErrorHandler.new(
          ::Cucumber::Distrib::Leader::CucumberHelper
        )
      end
    end
  end
end

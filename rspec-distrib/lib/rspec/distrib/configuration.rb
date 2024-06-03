require 'distrib_core/configuration'
require 'rspec/distrib/leader/tests_provider'
require 'rspec/distrib/leader/rspec_helper'

module RSpec
  module Distrib
    # Configuration holder
    #
    # Override default list of the test files:
    #
    #     RSpec::Distrib.configure do |config|
    #       config.tests_provider = -> {
    #         Dir.glob(['spec/**/*_spec.rb', 'engines/**/*_spec.rb'])
    #       }
    #     end
    #
    # Specify which errors should fail leader. Other errors will be retried, here you can specify how many times.
    #
    #     RSpec::Distrib.configure do |config|
    #       config.error_handler.retryable_exceptions = ['Elasticsearch::ServiceUnavailable']
    #       config.error_handler.retry_attempts = 2
    #       config.error_handler.fatal_worker_failures = ['NameError']
    #       config.error_handler.failed_workers_threshold = 2
    #     end
    #
    # Or set your own logic for retries.
    # It should respond to `#retry_test?`, `#ignore_worker_failure?` methods
    #
    #     RSpec::Distrib.configure do |config|
    #       config.error_handler = MyErrorHandler
    #     end
    #
    # Set equal timeout for all spec files to 30 seconds:
    #
    #     RSpec::Distrib.configure do |config|
    #       config.test_timeout = 30 # seconds
    #     end
    #
    # Or you can specify timeout per spec file. An object that responds to `call` and receives
    # the spec file path as an argument. The proc returns the timeout in seconds.
    #
    #     RSpec::Distrib.configure do |config|
    #       config.test_timeout = ->(spec_file) do
    #         10 + 2 * average_execution_in_seconds(spec_file)
    #       end
    #     end
    #
    # Set how long leader will wait before first spec processed by workers. Leader will exit if
    # no specs picked in this period
    #
    #     RSpec::Distrib.configure do |config|
    #       config.first_test_picked_timeout = 10*60 # 10 minutes
    #     end
    #
    # Set how long leader will wait if workers stopped processing the queue. Leader will exit if
    # no specs picked in this period
    #
    #     RSpec::Distrib.configure do |config|
    #       config.tests_processing_stopped_timeout = 5*60 # 5 minutes
    #     end
    #
    # Specify which formatters you want to use using `add_leader_formatter` or `add_worker_formatter` methods.
    # See `RSpec.configuration.add_formatter` for more info
    #
    #     RSpec::Distrib.configure do |config|
    #       config.add_leader_formatter('html', 'summary.html') # add HTML formatter which writes to 'summary.html' file
    #       config.add_worker_formatter('progress') # add progress formatter (prints dots to the console)
    #     end
    #
    # Specify custom options for DRb service. Defaults are `{ safe_level: 1 }`
    # See `DRb::DRbServer.new` for complete list
    #
    #     RSpec::Distrib.configure do |config|
    #       config.drb = {safe_level: 1}
    #     end
    #
    # Specify custom block to pre-process examples before reporting them to the leader.
    # Useful to add additional information about workers.
    #
    #     RSpec::Distrib.configure do |config|
    #       config.before_test_report = -> (file_name, example_groups) do
    #         example_groups.each { |eg| eg.metadata[:custom] = 'foo' }
    #       end
    #     end
    #
    class Configuration
      include ::DistribCore::Configuration
      # Sets RSpec's `--color` option for workers with "force" mode, rewriting existing one
      # Possible values: :on, :off; by default it's :automatic
      # See https://github.com/rspec/rspec-core/blob/7510b747cdb028dea4feb56cef8062cea14640a5/lib/rspec/core/configuration.rb#L937
      attr_accessor :worker_color_mode

      def initialize
        super
        @tests_provider = ::RSpec::Distrib::Leader::TestsProvider
        @error_handler = ::DistribCore::Leader::ErrorHandler.new(
          ::RSpec::Distrib::Leader::RSpecHelper
        )
      end

      # @return [Array<Object>]
      def leader_formatters
        @leader_formatters ||= []
      end

      # @param formatter [Object]
      # @param output [IO, String]
      def add_leader_formatter(formatter, output = nil)
        leader_formatters << (output ? [formatter, output] : [formatter])
      end

      # @return [Array<Object>]
      def worker_formatters
        @worker_formatters ||= []
      end

      # @param formatter [Object]
      # @param output [IO, String]
      def add_worker_formatter(formatter, output = nil)
        worker_formatters << (output ? [formatter, output] : [formatter])
      end
    end
  end
end

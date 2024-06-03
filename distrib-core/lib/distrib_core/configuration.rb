require 'logger'
require 'distrib_core/leader/error_handler'
require 'distrib_core/leader/retry_on_different_error_handler'
require 'distrib_core/logger_broadcaster'

module DistribCore
  # This module contains shared attrs instantiated by specific configuration classes.
  #
  # @see DistribCore::Distrib#configure
  module Configuration
    class << self
      # Set global configuration. Can be set only one time
      #
      # @param configuration [DistribCore::Configuration]
      def current=(configuration)
        raise('Configuration is already set') if @current && @current != configuration

        @current = configuration
      end

      # @return [DistribCore::Configuration] global configuration
      def current
        @current || raise('Configuration is not set')
      end
    end

    TIMEOUT_STRATEGIES = %i[repush release].freeze

    # @example Override default list of the tests:
    #     ...configure do |config|
    #       config.tests_provider = -> {
    #         Dir.glob(['features/**/*_feature.rb', 'engines/**/*_feature.rb'])
    #       }
    #     end
    attr_writer :tests_provider

    # @example Specify object to process exceptions during execution
    #     ...configure do |config|
    #       config.error_handler = MyErrorHandler.new
    #     end
    attr_writer :error_handler

    attr_writer :logger

    # @example Set equal timeout for all tests to 30 seconds:
    #     ...configure do |config|
    #       config.test_timeout = 30 # seconds
    #     end
    #
    # @example  Or you can specify timeout per test. An object that responds to `call` and receives the test as an argument. The proc returns the timeout in seconds.
    #     ...configure do |config|
    #       config.test_timeout = ->(test) do
    #         10 + 2 * average_execution_in_seconds(test)
    #       end
    #     end
    attr_accessor :test_timeout

    # @example Set how long leader will wait before first test processed by workers. Leader will exit if no tests picked in this period
    #     ...configure do |config|
    #       config.first_test_picked_timeout = 10*60 # 10 minutes
    #     end
    attr_accessor :first_test_picked_timeout

    # @example Specify custom options for DRb service. Defaults are `{ safe_level: 1 }`. @see `DRb::DRbServer.new` for complete list
    #     ...configure do |config|
    #       config.drb = {safe_level: 0, verbose: true}
    #     end
    attr_accessor :drb

    # @example Specify custom block to pre-process examples before reporting them to the leader. Useful to add additional information about workers.
    #     ...configure do |config|
    #       config.before_test_report = -> (file_name, example_groups) do
    #         example_groups.each { |eg| eg.metadata[:custom] = 'foo' }
    #       end
    #     end
    attr_accessor :before_test_report

    # @example Specify custom block which will be called on leader after run.
    #     ...configure do |config|
    #       config.on_finish = -> () do
    #         'Whatever logic before leader exit'
    #       end
    #     end
    attr_accessor :on_finish

    # @example Disable (mute) debug logger
    #     ...configure do |config|
    #       config.debug_logger = Logger.new(nil)
    #     end
    attr_writer :debug_logger

    attr_accessor :tests_processing_stopped_timeout, :drb_tcp_socket_connection_timeout, :leader_connection_attempts
    attr_reader :timeout_strategy

    # Initialize configuration with default values and set it to {DistribCore::Configuration.current}
    def initialize
      DistribCore::Configuration.current = self

      @test_timeout = 60 # 1 minute
      @first_test_picked_timeout = 10 * 60 # 10 minutes
      @tests_processing_stopped_timeout = 5 * 60 # 5 minutes
      @drb = { safe_level: 1 }
      @drb_tcp_socket_connection_timeout = 5 # 5 seconds
      @leader_connection_attempts = 200
      self.timeout_strategy = :repush
    end

    # Provider for tests to execute
    #
    # @return [Proc, Object#call] an object which responds to `#call`
    def tests_provider
      @tests_provider || raise(NotImplementedError)
    end

    # Object to handle errors from workers
    def error_handler
      @error_handler || raise(NotImplementedError)
    end

    # Gives a timeout for a particular test based on `#test_timeout`
    #
    # @see #test_timeout
    #
    # @param test [String] a test
    # @return [Float] timeout in seconds
    def timeout_for(test)
      test_timeout.respond_to?(:call) ? test_timeout.call(test) : test_timeout
    end

    # @return [Logger]
    def logger
      @logger ||= Logger.new($stdout, level: :info)
    end

    # Set how Watchdog will handle timed out test.
    def timeout_strategy=(value)
      unless TIMEOUT_STRATEGIES.include?(value)
        raise "Invalid Timeout Strategy. Given: #{value.inspect}. Expected one of: #{TIMEOUT_STRATEGIES.inspect}"
      end

      @timeout_strategy = value
    end

    # Main logging interface used by distrib.
    #
    # @return [LoggerBroadcaster]
    # @api private
    def broadcaster
      @broadcaster ||= LoggerBroadcaster.new([logger, debug_logger])
    end

    # Debugging logger. However user configures `logger`,
    # this one collects messages logged at all levels.
    #
    # @return [Logger]
    # @api private
    def debug_logger
      @debug_logger ||= Logger.new('distrib.log', level: :debug)
    end
  end
end

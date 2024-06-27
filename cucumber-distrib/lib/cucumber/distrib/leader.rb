require 'drb/drb'

require 'distrib_core/leader'
require 'distrib_core/drb_helper'
require 'distrib_core/metrics'
require 'cucumber'
require 'cucumber/distrib'
require 'cucumber/distrib/events'
require 'cucumber/distrib/leader/reporter'

module Cucumber
  module Distrib
    # Interface exposed over the network that Workers connect to in order to
    # receive test file names and report back the results to.
    #
    # Transport used is [DRb](https://rubydoc.info/stdlib/drb/DRb).
    class Leader # rubocop:disable Metrics/ClassLength
      include ::DistribCore::Leader

      # Used to interpolate with leader IP in order to generate the actual DRb server URL.
      DRB_SERVER_URL = 'druby://%s:8788'.freeze

      # Special event bus, ignores gherkin_source_read and test_case_ready events.
      class LocalEventBus < ::Cucumber::Core::EventBus
        # Because of exception raised about this method not defined.
        #
        # @return [nil]
        def gherkin_source_read(*); end

        # This event was introduced in the message formatter (https://github.com/cucumber/cucumber-ruby/pull/1387).
        #
        # The event is sent after applying the hooks:
        # https://github.com/cucumber/cucumber-ruby/blob/2dbf397352efc92c02f4d1d6d3196f1448db94ba/lib/cucumber/filters/broadcast_test_case_ready_event.rb#L7
        # https://github.com/cucumber/cucumber-ruby/blob/2dbf397352efc92c02f4d1d6d3196f1448db94ba/lib/cucumber/runtime.rb#L260
        #
        # We can ignore it as we already use the test_case_started which is triggered in Test::Runner.
        # https://github.com/cucumber/cucumber-ruby-core/blob/785d215e7169ff720a83a5e7f640470cbd8909fb/lib/cucumber/core/test/runner.rb#L18
        #
        # @return [nil]
        def test_case_ready(*); end
      end

      class << self
        # Starts the DRb server with exposed instance of the class.
        # Prepares queue of tests, starts Watchdog thread.
        #
        # @see DistribCore::Leader::Watchdog
        #
        # @param profiles [Array<String>] a list of profiles for Leader and workers
        # @param paths [Array<String>] a list of directories from which list of local tests will be build
        # @return [Integer] Exit code
        #
        # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        def start_service(profiles:, paths: [])
          tests = ::DistribCore::Leader::QueueBuilder.tests

          # Workaround over existing tests that pass list of files not scenarios.
          unless ENV['CUCUMBER_DISTRIB_FOLDER']
            tests = filter_provided_tests(
              tests:,
              profiles:,
              paths:
            )
          end

          queue = ::DistribCore::Leader::QueueWithLease.new(tests)

          logger.info "#{tests.count} tests have been enqueued"

          # We need to initialize Cucumber::Runtime to make reporters work.
          runtime = prepare_runtime(profiles)
          reporter = Cucumber::Distrib::Leader::Reporter.new(runtime)

          leader = new(queue, profiles, reporter, runtime)

          watchdog = ::DistribCore::Leader::Watchdog.new(queue)
          watchdog.start

          msg = Cucumber::Messages::Envelope.new(
            meta: Cucumber::CreateMeta.create_meta('cucumber-ruby', Cucumber::VERSION)
          )

          meta_event = Cucumber::Distrib::Events::Envelope.new(msg)
          runtime.configuration.event_bus.broadcast(meta_event)

          DRb.start_service(DRB_SERVER_URL % '0.0.0.0', leader, Cucumber::Distrib.configuration.drb)
          logger.info 'Leader ready'
          ::DistribCore::Metrics.queue_exposed
          DRb.thread.join

          reporter.report_test_run_finished
          Cucumber::Distrib.configuration.on_finish&.call

          failed = runtime.failure? || watchdog.failed? || leader.non_example_exception
          count_mismatch = (queue.size + queue.completed_size != tests.count)

          # NOTE: runtime.features stays empty for the whole run. It may affect statistics.
          if Cucumber.wants_to_quit || failed || ::DistribCore::ReceivedSignals.any? || count_mismatch
            print_failure_status(runtime, watchdog, leader, queue, count_mismatch)
            Kernel.exit(::DistribCore::ReceivedSignals.any? ? ::DistribCore::ReceivedSignals.exit_code : 1)
          else
            logger.info "Build succeeded. Tests processed: #{queue.completed_size}"
          end
        end
        # rubocop:enable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity

        # Filter list of provided tests (scenarios/test cases),
        # to include only those matching selected profiles.
        def filter_provided_tests(tests:, profiles:, paths:)
          return tests if tests.empty?

          locations = filtered_test_cases(profiles:, paths:)
          tests.intersection(locations)
        end

        private

        def filtered_test_cases(profiles:, paths:)
          locations = []
          event_bus = prepare_local_event_bus
          event_bus.on(:test_case_started) { |event| locations << event.test_case.location.to_s }

          compile_runtime(profiles:, paths:, event_bus:)

          # Sanitize locations of outline examples:
          # scenario.feature:example_line:outline_line -> scenario.feature:example_line
          locations.map do
            location_file, location_example, location_outline = _1.split(':')
            location_outline ? "#{location_file}:#{location_example}" : _1
          end
        end

        def compile_runtime(profiles:, paths:, event_bus:)
          configuration = Hash(prepare_cli_configuration(profiles))
                          .merge(dry_run: true, event_bus:, paths:)

          runtime = ::Cucumber::Runtime.new(configuration)
          runner = ::Cucumber::Core::Test::Runner.new(event_bus)

          # `compile` will parse features, filter them, and schedule to `event_bus`.
          runtime.compile(runtime.send(:features), runner, runtime.send(:filters), event_bus)
        end

        def prepare_local_event_bus
          LocalEventBus.new
        end

        def prepare_runtime(profiles)
          configuration = prepare_configuration(profiles)

          # We use Runtime here to prepare all necessary wires for formatters.
          ::Cucumber::Runtime.new(configuration).tap do |runtime|
            runtime.visitor = runtime.send :report
          end
        end

        def prepare_configuration(profiles)
          Hash(prepare_cli_configuration(profiles)).merge(
            # Use custom events registry since we use custom events:
            event_bus: ::Cucumber::Core::EventBus.new(::Cucumber::Distrib::Events.leader_registry)
          )
        end

        def prepare_cli_configuration(profiles)
          # Mimic console-line arguments:
          args = profiles.flat_map { |profile| ['--profile', profile] }

          ::Cucumber::Cli::Main.new(args).configuration
        end

        # rubocop:disable Metrics/AbcSize
        def print_failure_status(runtime, watchdog, leader, queue, count_mismatch)
          logger.info 'Build failed'
          logger.debug ::DistribCore::ReceivedSignals.message if ::DistribCore::ReceivedSignals.any?
          logger.debug 'Runtime failed' if runtime.failure?
          logger.debug 'Watchdog failed' if watchdog.failed?
          logger.debug 'Non example exception' if leader.non_example_exception
          logger.debug "Tests completed: #{queue.completed_size}"
          logger.debug "Tests left: #{queue.size}" if queue.size
          logger.warn "Amount of processed tests doesn't match amount of enqueued tests" if count_mismatch
        end
        # rubocop:enable Metrics/AbcSize
      end

      # Object shared through DRb is open for any calls. Including eval calls.
      # A simple way to prevent it - undef.
      undef :instance_eval
      undef :instance_exec

      attr_reader :non_example_exception, :profiles

      def initialize(queue, profiles, reporter, runtime)
        @queue = queue
        @profiles = profiles
        @reporter = reporter
        @runtime = runtime
        @run_started = false
      end

      # Get the next test from the queue.
      #
      # @return [String]
      drb_callable def next_test_to_run
        logger.debug 'Next test requested'

        unless run_started?
          @run_started = true
          reporter.report_test_run_started
          logger.debug 'Test run started'
        end

        ::DistribCore::Metrics.test_taken

        queue.lease.tap do |test|
          logger.debug "Serving #{test}"
        end
      end

      # Report events and exception for test.
      #
      # @see Cucumber::Distrib::Events
      #
      # @param test [String]
      # @param events [Array<Cucumber::Distrib::Events::Event>]
      # @param exception [Cucumber::Distrib::Events::Exception]
      #
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      drb_callable def report_test(test, events, exception = nil)
        message = "Reported #{test} with #{events.count} events"
        message += " and exception #{exception.original_class}" if exception
        logger.debug message

        return if queue.completed?(test)

        logger.debug "Test #{test} is not completed yet"

        if Cucumber::Distrib.configuration.error_handler.retry_test?(test, events, exception)
          logger.debug("Retrying #{test}")
          will_be_retried = true
          queue.repush(test)
          reporter.report_retrying_test(events.find { _1.is_a?(Cucumber::Distrib::Events::TestCaseFinished) })

          return {
            will_be_retried: true,
            events:
          }
        end

        logger.debug "Test #{test} is not retried"
        logger.debug 'Reporting events on leader side'
        reporter.report_events(events)

        logger.debug "Handling exception #{exception}" if exception
        handle_failed_worker(exception, test) if failed_worker?(exception)

        {
          will_be_retried: false,
          events:
        }
      ensure
        queue.release(test) unless will_be_retried
        log_completed_percent
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      # Report exception which prevented worker to start.
      #
      # @param exception [Cucumber::Distrib::Events::Exception]
      drb_callable def report_worker_configuration_error(exception)
        logger.info 'Reported configuration error from worker'

        return if Cucumber::Distrib.configuration.error_handler.ignore_worker_failure?(exception)

        handle_failed_worker(exception)
        nil
      end

      private

      attr_reader :queue, :runtime, :reporter

      def failed_worker?(exception)
        return false unless exception

        exception.message !~ /undefined method.*after_test_case/
      end

      def handle_failed_worker(exception, test = nil)
        message = "Leader will stop since worker failed with #{exception.original_class}"
        message += " on test #{test}:" if test
        message += "\n#{exception.message}"
        logger.error message
        logger.debug exception.backtrace&.join("\n")
        logger.debug exception.cause.inspect if exception.cause

        handle_non_example_exception
      end

      def handle_non_example_exception
        @non_example_exception = true
        DRb.current_server.stop_service
      end

      def log_completed_percent # rubocop:disable Metrics/AbcSize
        @logged_percents ||= []
        log_every = 10

        completed_percent = (queue.completed_size.to_f / (queue.size + queue.completed_size) * 100).to_i
        bucket = completed_percent / log_every * log_every # convert 35 to 30

        return if @logged_percents.include?(bucket)

        @logged_percents << bucket

        logger.debug "Completed: #{completed_percent}%"
      end

      def run_started?
        @run_started
      end
    end
  end
end

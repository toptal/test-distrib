require 'drb'
require 'cucumber'

require 'distrib_core/core_ext/drb_tcp_socket'
require 'distrib_core/worker'

require 'cucumber/distrib/leader'
require 'cucumber/distrib/worker/event_bus'
require 'cucumber/distrib/events'

module Cucumber
  module Distrib
    module Worker
      # Modified runner for Cucumber to consume and run tests from Leader.
      #
      # @see https://github.com/cucumber/cucumber-ruby/blob/master/lib/cucumber/runtime.rb
      class CucumberRunner < ::Cucumber::Runtime # rubocop:disable Metrics/ClassLength
        include ::DistribCore::Worker

        # Public method that invokes the runner.
        #
        # @param leader_ip [String]
        def self.run_from_leader(leader_ip)
          leader = ::DRbObject.new_with_uri(Leader::DRB_SERVER_URL % leader_ip)
          new(leader).run!
        end

        # Connects to Leader and loads configuration using profiles received from Leader.
        #
        # @see Cucumber::Runtime#initialize
        #
        # @param leader [DRbObject]
        def initialize(leader)
          @leader = leader
          profiles = connect_to_leader_with_timeout { leader.profiles }

          handle_configuration_failure do
            super(prepare_configuration(profiles))
          end
        end

        # Loads definitions of steps and executes features from Leader.
        #
        # @see Cucumber::Runtime#run!
        # @note
        #   Originally it loads all step definitions and executes all features.
        #   We change it behaviour to consume queue of Leader.
        def run! # rubocop:disable Metrics/MethodLength
          receiver = nil

          handle_configuration_failure do
            # This 5 lines below are the same as in the original code.
            load_step_definitions
            install_wire_plugin
            # Fire if defined.
            fire_after_configuration_hook if defined?(:fire_after_configuration_hook)
            fire_install_plugin_hook if defined?(:fire_install_plugin_hook)
            self.visitor = report
            receiver = Cucumber::Core::Test::Runner.new(@configuration.event_bus)
          end

          consume_queue(receiver)

          @configuration.notify :test_run_finished

          exit_code = determine_exit_code
          logger.info "Worker exiting with exit code #{exit_code}..."

          exit_code
        end

        private

        attr_reader :leader, :feature_file, :non_example_exception

        def prepare_configuration(profiles)
          # Mimic console-line arguments.
          args = profiles.each.with_object([]) { |p, acc| acc << '-p' << p }
          cli_configuration = ::Cucumber::Cli::Main.new(args).configuration

          Hash(cli_configuration).merge(
            # Use custom EventBus to collect events for Leader:
            event_bus: Cucumber::Distrib::Worker::EventBus.new
          )
        end

        # Redefined method to return only one feature to run.
        #
        # @note
        #   #features method uses on this one.
        def filespecs
          @filespecs ||= ::Cucumber::FileSpecs.new([feature_file])
        end

        # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        def consume_queue(receiver)
          @reported_filespecs = []
          @reported_features = []
          return if received_any_signal?

          while (test = leader.next_test_to_run)
            logger.debug "Running #{test}"

            reset_state

            @feature_file = test
            compile features, receiver, filters, @configuration.event_bus

            # Should not send a possible broken report for the leader.
            # A report can be broken because other services (e.g. Redis, Elasticsearch) could have already terminated.
            break if received_term? || received_force_int?

            report_test_to_leader(test, @configuration.event_bus.events_for_leader)
            logger.debug "Finished #{test}"

            break if received_int?
          end
        rescue DRb::DRbConnError
          # It raises when Leader is disconnected = a.k.a. queue is empty.
          logger.info 'Disconnected from leader, finishing'
        rescue Exception => e # rubocop:disable Lint/RescueException
          silently do
            report_test_to_leader(test, @configuration.event_bus.events_for_leader, e)
          end

          raise
        ensure
          # Putting features back to the local vars, so that results are consistent.
          restore_full_state
        end
        # rubocop:enable Metrics/AbcSize,Metrics/MethodLength

        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
        def report_test_to_leader(test, events, exception = nil)
          logger.debug "Reporting #{test} with #{events.size} events#{" and exception #{exception.class}" if exception}"

          converted_events = events.map { |e| Cucumber::Distrib::Events.convert(e) }
          converted_exception = Cucumber::Distrib::Events::Exception.new(exception) if exception

          if Cucumber::Distrib.configuration.before_test_report
            instance_exec(
              test,
              converted_events,
              converted_exception,
              &Cucumber::Distrib.configuration.before_test_report
            )
          end

          result = leader.report_test(test, converted_events, converted_exception)
          @configuration.notify :test_reported, result if result
        rescue DRb::DRbConnError => e
          @non_example_exception = true if ::DistribCore::DRbHelper.dump_failed?(e, events + [exception])
          raise
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity

        def handle_configuration_failure
          yield
        rescue Exception => e # rubocop:disable Lint/RescueException
          silently do
            converted_exception = Cucumber::Distrib::Events::Exception.new(e)
            leader.report_worker_configuration_error(converted_exception)
          end

          raise
        end

        def silently
          yield unless received_term? || received_force_int?
          # we don't care if it fails
        rescue StandardError # rubocop:disable Lint/SuppressedException
        end

        # Reset inner state to run new test.
        def reset_state
          @configuration.event_bus.events_for_leader.clear
          @reported_filespecs.concat(@filespecs&.locations&.map(&:to_s) || [])
          @reported_features.concat(@features || [])
          @features = nil
          @filespecs = nil
        end

        # Restore inner state to place back all executed features and filespecs.
        def restore_full_state
          reset_state
          @filespecs = ::Cucumber::FileSpecs.new(@reported_filespecs)
          @features = @reported_features + (@features || [])
        end

        def determine_exit_code
          if received_any_signal?
            logger.info ::DistribCore::ReceivedSignals.message
            return ::DistribCore::ReceivedSignals.exit_code
          end

          return 1 if Cucumber.wants_to_quit || failure? || non_example_exception

          0
        end
      end
    end
  end
end

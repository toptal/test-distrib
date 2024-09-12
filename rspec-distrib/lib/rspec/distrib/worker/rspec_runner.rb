require 'drb/drb'
require 'rspec/core'
require 'rspec/core/configuration_options'

require 'distrib_core/core_ext/drb_tcp_socket'
require 'distrib_core/worker'
require 'distrib_core/drb_helper'

require 'rspec/distrib/example_group'
require 'rspec/distrib/leader'
require 'rspec/distrib/worker/leader_reporter'
require 'rspec/distrib/worker/configuration'

module RSpec
  module Distrib
    module Worker
      # Modified RSpec runner to consume files from the leader.
      #
      # @see https://github.com/rspec/rspec-core/blob/master/lib/rspec/core/runner.rb
      class RSpecRunner < RSpec::Core::Runner # rubocop:disable Metrics/ClassLength
        include ::DistribCore::Worker

        # Public method that invokes the runner.
        #
        # @param leader_ip [String]
        def self.run_from_leader(leader_ip)
          leader = DRbObject.new_with_uri(Leader::DRB_SERVER_URL % leader_ip)
          new(leader).run
        end

        # @see RSpec::Core::Runner#initialize
        # @param leader [DRbObject]
        def initialize(leader) # rubocop:disable Metrics/MethodLength
          @success = true
          @leader = leader
          @seed = connect_to_leader_with_timeout { leader.seed }

          handle_configuration_failure do
            @options = RSpec::Core::ConfigurationOptions.new(["--seed=#{@seed}"])
            # As long as there is this assignment to global variable
            # the test have to restore RSpec.configuration after the example
            #
            # see `around` block in spec/rspec/distrib/worker/rspec_runner_spec.rb
            @configuration = RSpec.configuration = RSpec::Distrib::Worker::Configuration.new
            @configuration.leader = leader
            init_formatters
            @world = RSpec.world
            setup($stdout, $stderr)
          end
        end

        # @see RSpec::Core::Runner#run
        # @see RSpec::Core::Runner#run_specs
        #
        # @note
        #   Originally it makes setup and runs specs.
        #   We patch this method to consume from the leader, instead of the given
        #   example_groups param.
        def run(*) # rubocop:disable Metrics/MethodLength
          handle_configuration_failure do
            @configuration.reporter.report(Leader::FAKE_TOTAL_EXAMPLES_COUNT) do |reporter|
              @configuration.with_suite_hooks do
                # Disable handler since consume_queue has it's own handler.
                @handle_configuration_failure = false
                consume_queue(reporter)
              end
            end
          end

          persist_example_statuses
          return ::DistribCore::ReceivedSignals.exit_code if received_any_signal?

          success && !world.non_example_failure ? 0 : @configuration.failure_exit_code
        end

        private

        attr_reader :leader, :world, :success

        def init_formatters
          RSpec::Distrib.configuration.worker_formatters.each do |(formatter, *args)|
            RSpec.configuration.add_formatter(formatter, *args)
          end
        end

        # Runs specs from the leader until it is empty.
        #
        # @param reporter [RSpec::Core::Reporter]
        #
        # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        def consume_queue(reporter)
          @reported_examples = []
          return if received_any_signal?

          while (file_path = leader.next_file_to_run)
            logger.debug "Running #{file_path}"
            reset_reporter(reporter)
            load_spec_file(file_path)

            @success &= world.ordered_example_groups.map { |example_group| example_group.run(reporter) }.all?

            # Should not send a possible broken report for the leader.
            # A report can be broken because other services (e.g. Redis, Elasticsearch) could have already terminated.
            break if received_term? || received_force_int?

            report_file_to_leader(file_path, world.ordered_example_groups)

            break if received_int? || world.non_example_failure
          end
        rescue DRb::DRbConnError
          # It raises when Leader is disconnected = a.k.a. queue is empty.
          logger.info 'Disconnected from leader, finishing'
        rescue Exception => e # rubocop:disable Lint/RescueException
          # TODO: I'm unsure about this rescue, but we need to report all cases to leader
          silently do
            report_file_to_leader(file_path, world.ordered_example_groups, e)
          end
          raise
        ensure
          # Putting examples back to the local reporter, so that results are consistent.
          reporter.examples.concat(@reported_examples)
        end
        # rubocop:enable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity

        # Send the just processed example groups to leader, and concat these with an
        # array with the previous specs.
        #
        # We're doing that to keep consistency between Leader and Worker reports.
        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        def report_file_to_leader(file_path, example_groups, exception = nil)
          message = "Reporting #{file_path} with #{example_groups.count} example groups"
          message += " and exception #{exception.class}" if exception
          logger.debug message

          converted_example_groups = example_groups.map { |example_group| ExampleGroup.new(example_group) }
          converted_exception = RSpec::Distrib::ExecutionResults::Exception.new(exception) if exception

          if RSpec::Distrib.configuration.before_test_report
            instance_exec(
              file_path,
              converted_example_groups,
              converted_exception,
              &RSpec::Distrib.configuration.before_test_report
            )
          end

          leader.report_file(file_path, converted_example_groups, converted_exception)
        rescue DRb::DRbConnError => e
          dump_failed = ::DistribCore::DRbHelper.dump_failed?(e, converted_example_groups + [exception])
          world.non_example_failure = true if dump_failed
          raise
        end
        # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

        def handle_configuration_failure
          @handle_configuration_failure = true
          yield
        rescue Exception => e # rubocop:disable Lint/RescueException
          # TODO: I'm unsure about this rescue, but we need to report all cases to leader
          if @handle_configuration_failure
            silently do
              converted_exception = RSpec::Distrib::ExecutionResults::Exception.new(e)
              leader.report_worker_configuration_error(converted_exception)
            end
          end
          raise
        end

        def silently
          # we don't care if it fails
          yield unless received_term? || received_force_int?
        rescue StandardError
          nil
        end

        # This is a hack to be make world recognize the next spec file to run from
        # the leader.
        #
        # @param path [String] ex: 'spec/apq/actions/ba/talent/walkthrough/update_profile_spec.rb'
        #
        # @see RSpec::Core::Runner#configure
        # @see RSpec::Core::Runner#setup
        def load_spec_file(path)
          world.example_groups.clear
          @options = RSpec::Core::ConfigurationOptions.new(["--seed=#{@seed}", path])
          @options.configure(@configuration)

          if RSpec::Distrib.configuration.worker_color_mode
            @configuration.force(color_mode: RSpec::Distrib.configuration.worker_color_mode)
          end

          @configuration.load_spec_files
        end

        def reset_reporter(reporter)
          @reported_examples.concat(reporter.examples)
          reporter.examples.clear
        end

        def logger
          RSpec::Distrib.configuration.logger
        end
      end
    end
  end
end

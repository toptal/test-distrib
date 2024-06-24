require 'rspec/core'
require 'rspec/core/profiler'

require 'rspec/distrib/example_group'

module RSpec
  module Distrib
    class Leader
      # RSpec reporter local to the Leader, but reachable by Workers.
      # Used to accumulate the example execution results from worker machines.
      class Reporter
        # Failed statuses for an example
        FAILED_STATUSES = %w[failed].freeze
        # Possible example statuses
        REPORTABLE_EXAMPLE_STATUSES = (%w[passed pending] + FAILED_STATUSES).freeze

        def initialize
          @reporter = init_reporter
          @reporter.start(Leader::FAKE_TOTAL_EXAMPLES_COUNT)
        end

        # To report the file and all its specs results.
        #
        # We're doing this by file, so that the results keeps readable in any
        # format, even if multiple workers are sending results at the same time.
        #
        # @param example_group [RSpec::Distrib::ExampleGroup]
        # @see RSpec::Distrib::ExampleGroup
        #
        # @note This is only supporting RSpec "Progress" formatter for now.
        def report(example_group, will_be_retried: false)
          reporter.example_group_started(example_group)

          example_group.examples.each { |example| report_example(example, will_be_retried:) }
          example_group.children.each do |inner_example_group|
            report(inner_example_group, will_be_retried:)
          end

          reporter.example_group_finished(example_group)
        end

        # Print the final results of the test suite.
        def finish
          reporter.finish
        end

        # Notifies RSpec about exceptions unrelated to an example in order to halt execution.
        #
        # @param exception [Exception]
        def notify_non_example_exception(exception, context_description)
          reporter.notify_non_example_exception(exception, context_description)
        end

        def failures?
          reporter.failed_examples.any?
        end

        private

        attr_reader :reporter

        def init_reporter
          RSpec::Distrib.configuration.leader_formatters.each do |(formatter, *args)|
            RSpec.configuration.add_formatter(formatter, *args)
          end

          RSpec.configuration.reporter
        end

        # Adds example to report. Notifies formatters.
        def report_example(example_result, will_be_retried:)
          status = example_result.execution_result.status.to_s

          raise "Example status not valid: '#{status}'" unless REPORTABLE_EXAMPLE_STATUSES.include?(status)

          if will_be_retried
            # We retry the whole file, but we only want to
            # report the specs that actually failed and cause the retry.
            return unless FAILED_STATUSES.include?(status)

            reporter.publish(:example_will_be_retried, example: example_result)
          else
            reporter.example_started(example_result)
            reporter.example_finished(example_result)
            reporter.public_send("example_#{status}", example_result)
          end
        end
      end
    end
  end
end

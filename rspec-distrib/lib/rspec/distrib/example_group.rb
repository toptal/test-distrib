RSpec::Support.require_rspec_core 'formatters/exception_presenter'

module RSpec
  module Distrib
    # Helper to proxy getter methods to metadata attributes.
    module DelegateToMetadata
      # Defines methods that fetch attributes from metadata hash.
      #
      # @param keys [Array<String>]
      def delegate_to_metadata(*keys)
        keys.each { |key| define_method(key) { @metadata[key] } }
      end
    end

    # Objects that mimic an RSpec::Core::ExampleGroup on the Reporters.
    #
    # This is necessary because the RSpec::Core::ExampleGroup is quite large and not
    # Marshalable.
    #
    # So we send this object to the Leader instead of the real ExampleGroup.
    # @api private
    class ExampleGroup
      extend DelegateToMetadata

      attr_reader :class_name, :examples, :metadata, :children, :parent_example_group, :description

      delegate_to_metadata :described_class, :file_path, :location

      # @param [RSpec::Core::ExampleGroup] example_group
      # @param [RSpec::Distrib::ExampleGroup] parent_example_group
      def initialize(example_group, parent_example_group = nil)
        initialize_metadata(example_group.metadata)
        @class_name = example_group.name
        @parent_example_group = parent_example_group
        @children = example_group.children.map { |eg| ExampleGroup.new(eg, self) }
        @examples = example_group.filtered_examples.map { |e| ExampleResult.new(e, self) }
        @description = example_group.description
      end

      def superclass_metadata
        parent_example_group&.metadata
      end

      def descendant_filtered_examples
        @descendant_filtered_examples ||= [examples, children.map(&:descendant_filtered_examples)].flatten
      end

      def top_level?
        !parent_example_group
      end

      def top_level_description
        parent_groups.last.description
      end

      def parent_groups
        groups = [self]
        current_group = self

        while (current_group = current_group.parent_example_group)
          groups << current_group
        end

        groups
      end

      private

      def initialize_metadata(metadata)
        @metadata = metadata.slice(:description, :full_description,
                                   :file_path, :line_number, :location, :absolute_file_path,
                                   :rerun_file_path, :scoped_id)
        @metadata[:described_class] = metadata[:described_class]&.to_s
        @metadata[:description_args] = metadata[:description_args]&.map(&:to_s)
      end
    end

    # Objects that mimic an RSpec::Core::Example on the Reporters.
    #
    # This is necessary because the RSpec::Core::Example is quite large and not
    # Marshalable.
    #
    # So we send this object to the Leader instead of the real Example.
    # @api private
    class ExampleResult
      extend DelegateToMetadata

      attr_reader :example_group, :description, :location_rerun_argument,
                  :metadata, :example, :formatted_backtrace

      delegate_to_metadata :execution_result, :file_path, :full_description,
                           :location, :pending, :skip

      def initialize(example, example_group)
        initialize_metadata(example.metadata)
        @description = example.description
        @location_rerun_argument = example.location_rerun_argument
        @example_group = example_group
        exception_presenter = RSpec::Core::Formatters::ExceptionPresenter::Factory.new(example).build

        if example.exception # rubocop:disable Style/GuardClause
          colorizer = ::RSpec::Core::Notifications::NullColorizer
          # FIXME: figure out how to pass proper failure_number
          @fully_formatted_lines = exception_presenter.fully_formatted_lines(1, colorizer)
          @formatted_backtrace = exception_presenter.formatted_backtrace
        end
      end

      def exception
        execution_result.exception
      end

      def id
        "#{metadata[:rerun_file_path]}[#{metadata[:scoped_id]}]"
      end

      def fully_formatted_lines(_failure_number = nil, _colorizer = nil)
        @fully_formatted_lines
      end

      private

      def initialize_metadata(metadata)
        @metadata = metadata.slice(:extra_failure_lines,
                                   :rerun_file_path, :file_path, :full_description,
                                   :location, :pending, :skip, :scoped_id)
        @metadata[:execution_result] = ExecutionResults.new(metadata[:execution_result])
        @metadata[:shared_group_inclusion_backtrace] = metadata[:shared_group_inclusion_backtrace].map do |frame|
          SharedExampleGroupInclusionStackFrame.new(frame)
        end
      end
    end

    # Objects that mimic an RSpec::Core::Example::ExecutionResult on the Reporters.
    #
    # This is necessary because the RSpec::Core::Example is quite large and not
    # Marshalable.
    # @api private
    class ExecutionResults
      attr_reader :status, :pending_exception, :pending_message, :exception,
                  :run_time, :pending_fixed, :example_skipped

      def initialize(execution_results)
        @status = execution_results.status
        @pending_exception = Exception.new(execution_results.pending_exception) if execution_results.pending_exception
        @pending_message = execution_results.pending_message
        @exception = Exception.new(execution_results.exception) if execution_results.exception
        @example_skipped = execution_results.example_skipped?
        @pending_fixed = execution_results.pending_fixed?
        @run_time = execution_results.run_time
      end

      alias example_skipped? example_skipped
      alias pending_fixed? pending_fixed

      # Objects that mimic an Exception on the Reporters.
      #
      # This is necessary because some exceptions are quite large and not Marshalable.
      class Exception
        attr_reader :backtrace, :cause, :message, :original_class

        def initialize(exception) # rubocop:disable Metrics/MethodLength
          @original_class = if exception.is_a?(Class)
                              exception.to_s
                            else
                              exception.class.to_s
                            end

          if multiple_exceptions?(exception)
            initialize_as_multiple_exceptions(exception)
            return
          end

          @backtrace = exception.backtrace
          @cause = Exception.new(exception.cause) if exception.cause
          @message = exception.message
        end

        def set_backtrace(backtrace) # rubocop:disable Naming/AccessorMethodName as on original interface
          @backtrace = backtrace
        end

        private

        def multiple_exceptions?(exception)
          defined?(RSpec::Core::MultipleExceptionError) &&
            exception.is_a?(RSpec::Core::MultipleExceptionError)
        end

        def initialize_as_multiple_exceptions(exception)
          @backtrace = backtrace_for_multiple_exceptions(exception)
          @message = message_for_multiple_exceptions(exception)
          cause = exception.all_exceptions.first.cause
          @cause = Exception.new(cause) if cause
        end

        def backtrace_for_multiple_exceptions(exception)
          exceptions = exception.all_exceptions
          exceptions.map(&:backtrace).zip(Array.new(exceptions.count - 1, 'AND')).flatten.compact
        end

        def message_for_multiple_exceptions(exception)
          exceptions = exception.all_exceptions
          messages = exceptions.map { |e| "#{e.class.name}: #{e.message}" }.join("\n\nAND\n\n")
          "#{exception.summary}:\n#{messages}"
        end
      end
    end

    # Objects that mimic an RSpec::Core::SharedExampleGroupInclusionStackFrame on the Reporters.
    #
    # This is necessary because the original object refers to objects which can't be accessed on the leader.
    # @api private
    class SharedExampleGroupInclusionStackFrame
      attr_reader :shared_group_name, :inclusion_location, :formatted_inclusion_location, :description

      def initialize(frame)
        @shared_group_name = frame.shared_group_name.to_s
        @inclusion_location = frame.inclusion_location
        @formatted_inclusion_location = frame.formatted_inclusion_location
        @description = frame.description
      end
    end
  end
end

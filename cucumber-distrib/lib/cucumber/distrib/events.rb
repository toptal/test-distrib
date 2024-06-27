require 'rspec'
require 'cucumber/distrib/test'

module Cucumber
  module Distrib
    # Custom objects to represent events from workers on Leader for reporters.
    # This is necessary because original events are not Marshalable.
    class Events
      class << self
        # Convert core event.
        #
        # @param event [Cucumber::Core::Event]
        # @return [Cucumber::Distrib::Events::Event]
        def convert(event) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/CyclomaticComplexity
          case event
          when ::Cucumber::Events::Envelope
            Cucumber::Distrib::Events::Envelope.new(event)
          when ::Cucumber::Events::GherkinSourceParsed
            Cucumber::Distrib::Events::GherkinSourceParsed.new(event)
          when ::Cucumber::Events::GherkinSourceRead
            Cucumber::Distrib::Events::GherkinSourceRead.new(event)
          when ::Cucumber::Events::HookTestStepCreated
            Cucumber::Distrib::Events::HookTestStepCreated.new(event)
          when ::Cucumber::Events::StepActivated
            Cucumber::Distrib::Events::StepActivated.new(event)
          when ::Cucumber::Events::StepDefinitionRegistered
            Cucumber::Distrib::Events::StepDefinitionRegistered.new(event)
          when ::Cucumber::Events::TestCaseCreated
            Cucumber::Distrib::Events::TestCaseCreated.new(event)
          when ::Cucumber::Events::TestCaseFinished
            Cucumber::Distrib::Events::TestCaseFinished.new(event)
          when ::Cucumber::Events::TestCaseStarted
            Cucumber::Distrib::Events::TestCaseStarted.new(event)
          when ::Cucumber::Events::TestCaseReady
            Cucumber::Distrib::Events::TestCaseReady.new(event)
          when ::Cucumber::Events::TestStepCreated
            Cucumber::Distrib::Events::TestStepCreated.new(event)
          when ::Cucumber::Events::TestStepFinished
            Cucumber::Distrib::Events::TestStepFinished.new(event)
          when ::Cucumber::Events::TestStepStarted
            Cucumber::Distrib::Events::TestStepStarted.new(event)
          when ::Cucumber::Events::UndefinedParameterType
            Cucumber::Distrib::Events::UndefinedParameterType.new(event)
          else
            raise "Can't convert #{event}"
          end
        end

        # @return [Hash] custom event registry for workers
        def worker_registry
          ::Cucumber::Events.registry.merge ::Cucumber::Core::Events.build_registry(
            ::Cucumber::Distrib::Events::RetryingTest,
            ::Cucumber::Distrib::Events::TestReported
          )
        end

        # @return [Hash] custom event registry for Leader
        def leader_registry # rubocop:disable Metrics/MethodLength
          ::Cucumber::Events.registry.merge ::Cucumber::Core::Events.build_registry(
            ::Cucumber::Distrib::Events::Envelope,
            ::Cucumber::Distrib::Events::GherkinSourceParsed,
            ::Cucumber::Distrib::Events::GherkinSourceRead,
            ::Cucumber::Distrib::Events::HookTestStepCreated,
            # A distrib custom event to signal that a test has been reported to leader
            ::Cucumber::Distrib::Events::RetryingTest,
            ::Cucumber::Distrib::Events::StepActivated,
            ::Cucumber::Distrib::Events::StepDefinitionRegistered,
            ::Cucumber::Distrib::Events::TestCaseCreated,
            ::Cucumber::Distrib::Events::TestCaseFinished,
            ::Cucumber::Distrib::Events::TestCaseReady,
            ::Cucumber::Distrib::Events::TestCaseStarted,
            # A distrib custom event to signal that a test has been reported to leader
            ::Cucumber::Distrib::Events::TestReported,
            # Those are emitted on the leader side:
            # ::Cucumber::Distrib::Events::TestRunFinished,
            # ::Cucumber::Distrib::Events::TestRunStarted,
            ::Cucumber::Distrib::Events::TestStepCreated,
            ::Cucumber::Distrib::Events::TestStepFinished,
            ::Cucumber::Distrib::Events::TestStepStarted,
            ::Cucumber::Distrib::Events::UndefinedParameterType
          )
        end
      end

      # Base class for converted events.
      class Event
        # Used internaly by Cucumber.
        # @return [String]
        def self.event_id
          # It uses custom logic for `underscore` method.
          ::Cucumber::Core::Event.__send__(:underscore, name.split('::').last).to_sym
        end

        # Add custom metadata to events so we can transfer it between workers and Leader.
        # Should contain only Marshalable objects.
        #
        # @return [Hash]
        def metadata
          @metadata ||= {}
        end
      end

      # Base class for converted TestCase events.
      class BaseTestCaseEvent < Event
        attr_reader :test_case

        def initialize(event)
          super()
          @test_case = Cucumber::Distrib::Test::Case.new event.test_case
        end
      end

      # Base class for converted TestStep events.
      class BaseTestStepEvent < Event
        attr_reader :test_step

        def initialize(event)
          super()
          @test_step = Cucumber::Distrib::Test.adapt_test_step(event.test_step)
        end
      end

      # Object that mimic exception on the Leader for reporters.
      class Exception
        attr_reader :backtrace, :cause, :message, :original_class

        # @param exception [Exception]
        def initialize(exception, propagate_cause: true)
          @original_class = if exception.is_a?(Class)
                              exception.to_s
                            else
                              exception.class.to_s
                            end

          @backtrace = exception.backtrace
          @cause = Exception.new(exception.cause, propagate_cause: false) if exception.cause && propagate_cause
          @message = exception.message
        end

        # @param backtrace [Array<String>]
        def set_backtrace(backtrace) # rubocop:disable Naming/AccessorMethodName as on original interface
          @backtrace = backtrace
        end

        # This is used to present proper names for exceptions in cucumber reports.
        def class
          klass = original_class

          Class.new(::Cucumber::Distrib::Events::Exception).tap do |wrapper|
            wrapper.define_singleton_method :to_s do
              klass
            end

            wrapper.define_singleton_method :inspect do
              "Cucumber::Distrib::Events::Exception(#{self})"
            end
          end
        end
      end

      # Object that mimic Cucumber::Event::StepActivated on Leader for reporters.
      class Envelope < Event
        attr_reader :envelope

        def initialize(event)
          super()
          @envelope = event.is_a?(::Cucumber::Messages::Envelope) ? event : event.envelope
        end
      end

      # Object that mimics Cucumber::Event::GherkinSourceParsed on Leader for reporters.
      class GherkinSourceParsed < Event
        attr_reader :gherkin_document

        def initialize(event)
          super()
          @gherkin_document = event.gherkin_document
        end
      end

      # Object that mimics Cucumber::Event::GherkinSourceRead on Leader for reporters.
      class GherkinSourceRead < Event
        attr_reader :body, :path

        def initialize(event)
          super()
          @path = event.path
          @body = event.body
        end
      end

      # PORO wrapper of corresponding cucumber event for safe transportation to Leader over DRb.
      class Hook
        attr_reader :id

        def initialize(id)
          @id = id
        end
      end

      # PORO wrapper of corresponding cucumber event for safe transportation to Leader over DRb.
      class HookStep
        attr_reader :id

        def initialize(id)
          @id = id
        end
      end

      # Object that mimic Cucumber::Event::HookTestStepCreated on Leader for reporters.
      class HookTestStepCreated < Event
        attr_reader :test_step, :hook

        # @param event [Cucumber::Events::HookTestStepCreated]
        def initialize(event)
          super()
          @test_step = HookStep.new event.test_step.id
          @hook = Hook.new event.hook.id
        end
      end

      # PORO wrapper of corresponding cucumber event for safe transportation to Leader over DRb.
      class Pattern
        attr_reader :source, :type

        def initialize(pattern)
          @source = pattern.source
          @type = pattern.type
        end
      end

      # PORO wrapper of corresponding cucumber event for safe transportation to Leader over DRb.
      class SourceReference
        attr_reader :uri, :location

        def initialize(source_reference)
          @uri = source_reference.uri
          @location = source_reference.location
        end
      end

      # PORO wrapper of corresponding cucumber event for safe transportation to Leader over DRb.
      class Expression
        def initialize(expression = nil); end
      end

      # PORO wrapper of corresponding cucumber event for safe transportation to Leader over DRb.
      class StepDefinition
        attr_reader :id

        def initialize(step_definition)
          @id = step_definition.id
          @envelope = step_definition.to_envelope
        end
      end

      # PORO wrapper of corresponding cucumber event for safe transportation to Leader over DRb.
      class Group
        attr_reader :start, :value, :children

        def initialize(group)
          @start = group.start
          @value = group.value
          @children = group.children.map { |c| Group.new c }
        end
      end

      # PORO wrapper of corresponding cucumber event for safe transportation to Leader over DRb.
      class StepArgument
        attr_reader :group, :parameter_type

        def initialize(step_argument)
          @group = step_argument.group
          @parameter_type = step_argument.parameter_type.dup
          # Cannot pass lambda over DRb, pass a string literal instead.
          @parameter_type.instance_variable_set(:@transformer, 'asd')
          # Cannot pass types from platform app (like Role), as they are not loaded by the leader.
          @parameter_type.instance_variable_set(:@type, String)
        end
      end

      # PORO wrapper of corresponding cucumber event for safe transportation to Leader over DRb.
      class StepMatch
        attr_reader :step_definition, :step_arguments, :location

        def initialize(step_match)
          @step_definition = StepDefinition.new step_match.step_definition
          @step_arguments = step_match.step_arguments.map { |sa| StepArgument.new sa }
          @location = step_match.step_definition.location
          @name_to_match = step_match.step_definition.to_envelope.step_definition.pattern.source.to_s
        end

        def format_args(format = ->(a) { a }, &proc)
          replace_arguments(@name_to_match, @step_arguments, format, &proc)
        end

        def replace_arguments(string, step_arguments, format) # rubocop:disable Metrics/MethodLength
          s = string.dup

          step_arguments.each do |step_argument|
            group = step_argument.group
            next if group.value.nil?

            replacement = if block_given?
                            yield(group.value)
                          elsif format.instance_of?(Proc)
                            format.call(group.value)
                          else
                            format % group.value
                          end

            s.sub!(/\{[^}]+\}/, replacement)
          end

          s
        end
      end

      # Object that mimic Cucumber::Event::StepActivated on Leader for reporters.
      class StepActivated < BaseTestStepEvent
        attr_reader :step_match

        # @param event [Cucumber::Events::StepActivated]
        def initialize(event)
          super
          @step_match = StepMatch.new event.step_match
        end

        def attributes
          [test_step, step_match]
        end
      end

      # Object that mimic Cucumber::Event::StepDefinitionRegistered on Leader for reporters.
      class StepDefinitionRegistered < Event
        attr_reader :step_definition

        # @param event [Cucumber::Events::StepDefinitionRegistered]
        def initialize(event)
          super()
          @step_definition = StepDefinition.new event.step_definition
        end
      end

      # Object that mimic Cucumber::Event::TestCaseCreated on Leader for reporters.
      class TestCaseCreated < BaseTestCaseEvent
        attr_reader :pickle

        # @param event [Cucumber::Events::TestCaseCreated]
        def initialize(event)
          super
          @pickle = event.pickle
        end
      end

      # Object that mimic Cucumber::Event::TestCaseFinished on Leader for reporters.
      class TestCaseFinished < BaseTestCaseEvent
        attr_reader :result

        # @param event [Cucumber::Events::TestCaseFinished]
        def initialize(event)
          super

          if event.result.is_a? ::Cucumber::Core::Test::Result::Failed
            exception = ::Cucumber::Distrib::Events::Exception.new(event.result.exception)
            @result = ::Cucumber::Core::Test::Result::Failed.new(event.result.duration, exception)
          else
            @result = event.result
          end
        end

        # @return [Array<String>]
        def attributes
          [test_case, result]
        end
      end

      # Event for notification of retrying test.
      class RetryingTest < TestCaseFinished
        def initialize(event)
          super
          @metadata = event.metadata
        end
      end

      # Object that mimic Cucumber::Event::TestCaseReady on Leader for reporters.
      class TestCaseReady < BaseTestCaseEvent
      end

      # Object that mimic Cucumber::Event::TestCaseStarted on Leader for reporters.
      class TestCaseStarted < BaseTestCaseEvent
      end

      # Event to notify on worker side that a test has been reported to leader.
      class TestReported < Event
        attr_reader :payload

        # @param payload [Hash {will_be_retried: boolean, events: Array<Cucumber::Distrib::Events::Event>}]
        def initialize(payload)
          super()
          @payload = payload
        end
      end

      # Object that mimic Cucumber::Event::TestStepCreated on Leader for reporters.
      class TestStepCreated < BaseTestStepEvent
        attr_reader :pickle_step

        # @param event [Cucumber::Events::TestStepCreated]
        def initialize(event)
          super
          @pickle_step = event.pickle_step
        end
      end

      # Object that mimic Cucumber::Event::TestStepFinished on Leader for reporters
      class TestStepFinished < BaseTestStepEvent
        attr_reader :result

        # @param event [Cucumber::Events::TestStepFinished]
        def initialize(event)
          super

          if event.result.is_a? ::Cucumber::Core::Test::Result::Failed
            exception = ::Cucumber::Distrib::Events::Exception.new(event.result.exception)
            @result = ::Cucumber::Core::Test::Result::Failed.new(event.result.duration, exception)
          else
            @result = event.result
          end
        end

        # @return [Array<String>]
        def attributes
          [test_step, result]
        end
      end

      # Object that mimic Cucumber::Event::TestStepStarted on Leader for reporters.
      class TestStepStarted < BaseTestStepEvent
      end

      # Object that mimic Cucumber::Event::UndefinedParameterType on Leader for reporters.
      class UndefinedParameterType < Event
        attr_reader :type_name, :expression

        # @param event [Cucumber::Events::UndefinedParameterType]
        def initialize(event)
          super()
          @type_name = event.type_name
          @expression = Expression.new
        end
      end
    end
  end
end

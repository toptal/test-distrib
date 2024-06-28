module Cucumber
  module Distrib
    # Custom objects to represent core objects from workers on Leader for reporters.
    # This is necessary because original objects are not Marshalable.
    module Test
      def self.adapt_test_step(test_step)
        if test_step.is_a?(Cucumber::Core::Test::HookStep)
          Cucumber::Distrib::Test::HookStep.new(test_step)
        else
          Cucumber::Distrib::Test::Step.new(test_step)
        end
      end

      # Object that mimic Cucumber::Core::Test::Case on Leader for reporters.
      class Case < Core::Test::Case
        # @param test_case [Cucumber::Core::Test::Case]
        def initialize(test_case) # rubocop:disable Lint/MissingSuper
          @id = test_case.id
          @name = test_case.name
          @test_steps = test_case.test_steps.map { |test_step| Test.adapt_test_step(test_step) }
          @location = test_case.location
          @tags = test_case.tags
          @language = test_case.language
          @around_hooks = []
        end
      end

      # Object that mimic Cucumber::Core::Test::Step on Leader for reporters.
      class Step < Core::Test::Step
        # @param test_step [Cucumber::Core::Test::Step]
        def initialize(test_step) # rubocop:disable Lint/MissingSuper
          @id = test_step.id
          @text = test_step.text
          @location = test_step.location
          @multiline_arg = test_step.multiline_arg
        end
      end

      # Object that mimics Cucumber::Core::Test::HookStep on Leader for reporters.
      class HookStep < Core::Test::HookStep
        # @param test_step [Cucumber::Core::Test::Step]
        def initialize(test_step) # rubocop:disable Lint/MissingSuper
          @id = test_step.id
          @text = test_step.text
          @location = test_step.location
          @multiline_arg = test_step.multiline_arg
        end
      end
    end
  end
end

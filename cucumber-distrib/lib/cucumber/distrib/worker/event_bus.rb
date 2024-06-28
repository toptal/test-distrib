module Cucumber
  module Distrib
    module Worker
      # Custom EventBus to collect specific events for Leader.
      # @see Cucumber::Distrib::Events
      class EventBus < ::Cucumber::Core::EventBus
        # List of events to collect for Leader.
        EVENTS_FOR_LEADER = [
          ::Cucumber::Events::Envelope,
          ::Cucumber::Events::GherkinSourceParsed,
          ::Cucumber::Events::GherkinSourceRead,
          ::Cucumber::Events::HookTestStepCreated,
          ::Cucumber::Events::StepActivated,
          ::Cucumber::Events::StepDefinitionRegistered,
          ::Cucumber::Events::TestCaseCreated,
          ::Cucumber::Events::TestCaseFinished,
          ::Cucumber::Events::TestCaseReady,
          ::Cucumber::Events::TestCaseStarted,
          # Those are emitted on the leader side:
          # ::Cucumber::Events::TestRunFinished,
          # ::Cucumber::Events::TestRunStarted,
          ::Cucumber::Events::TestStepCreated,
          ::Cucumber::Events::TestStepFinished,
          ::Cucumber::Events::TestStepStarted,
          ::Cucumber::Events::UndefinedParameterType
        ].freeze

        attr_reader :events_for_leader

        # Initialized with {Cucumber::Distrib::Events.worker_registry}.
        def initialize
          @events_for_leader = []
          super(Cucumber::Distrib::Events.worker_registry)
        end

        # Broadcast an event, but collects it for Leader.
        # @param event [Cucumber::Core::Event]
        def broadcast(event)
          super.tap do
            # Collect specific events to send them to Leader after file finishes.
            @events_for_leader << event if EVENTS_FOR_LEADER.any? { |c| event.is_a? c }
          end
        end
      end
    end
  end
end

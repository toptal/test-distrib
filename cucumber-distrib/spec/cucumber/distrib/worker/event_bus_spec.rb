# frozen_string_literal: true

RSpec.describe Cucumber::Distrib::Worker::EventBus do
  subject(:event_bus) { described_class.new }

  it 'initialized with proper registry' do
    expect(event_bus.event_types).to eq(Cucumber::Distrib::Events.worker_registry)
  end

  it 'collects TestCase* and TestStep* progress events' do
    events = [
      Cucumber::Events::TestCaseStarted.new,
      Cucumber::Events::TestCaseFinished.new,
      Cucumber::Events::TestStepFinished.new,
      Cucumber::Events::TestStepStarted.new,
      Cucumber::Events::StepDefinitionRegistered.new(''),
      Cucumber::Events::StepActivated.new('', ''),
      Cucumber::Events::TestRunFinished.new,
      Cucumber::Events::GherkinSourceRead.new,
      Cucumber::Events::TestRunStarted.new
    ]

    events.each { |event| event_bus.broadcast(event) }
    expect(event_bus.events_for_leader).to include(*events.first(4))
  end
end

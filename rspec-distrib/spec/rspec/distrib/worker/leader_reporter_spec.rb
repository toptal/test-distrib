# frozen_string_literal: true

RSpec.describe RSpec::Distrib::Worker::LeaderReporter do
  describe '#notify_non_example_exception' do
    subject(:reporter) { described_class.new(leader, rspec_reporter) }

    let(:leader) { instance_double(RSpec::Distrib::Leader) }
    let(:rspec_reporter) { instance_double(RSpec::Core::Reporter).as_null_object }

    it 'notifies the leader' do
      expect(leader).to receive(:notify_non_example_exception)
        .with(an_instance_of(RSpec::Distrib::ExecutionResults::Exception), :context_description)
      reporter.notify_non_example_exception(Exception.new, :context_description)
    end
  end
end

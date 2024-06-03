# frozen_string_literal: true

RSpec.describe RSpec::Distrib::Worker::Configuration do
  subject(:configuration) { described_class.new.tap { |o| o.leader = leader } }

  let(:leader) { instance_double(RSpec::Distrib::Leader) }

  it do
    expect(configuration.formatter_loader.reporter).to be_an_instance_of(RSpec::Distrib::Worker::LeaderReporter)
  end

  it { expect(configuration.seed_used?).to be true }
end

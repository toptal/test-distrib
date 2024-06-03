# frozen_string_literal: true

require 'distrib_core/spec/configuration'

RSpec.describe RSpec::Distrib::Configuration do
  subject(:configuration) { RSpec::Distrib.configuration }

  around do |example|
    config = RSpec::Distrib.instance_variable_get(:@configuration)
    RSpec::Distrib.instance_variable_set(:@configuration, nil)
    example.run
    RSpec::Distrib.instance_variable_set(:@configuration, config)
  end

  it '#tests_provider' do
    expect(configuration.tests_provider)
      .to eq(RSpec::Distrib::Leader::TestsProvider)
  end

  it '#error_handler' do
    expect(configuration.error_handler)
      .to be_a(RSpec::Distrib::Leader::ErrorHandler)
  end

  it 'has no leader_formatters' do
    expect(configuration.leader_formatters).to be_empty
  end

  it 'has no worker_formatters' do
    expect(configuration.worker_formatters).to be_empty
  end

  it 'can add leader_formatters' do
    RSpec::Distrib.configure do |config|
      config.add_leader_formatter('html', 'output.html')
    end

    expect(configuration.leader_formatters).to include(%w[html output.html])
  end

  it 'can add worker_formatters' do
    RSpec::Distrib.configure do |config|
      config.add_worker_formatter('html', 'output.html')
    end

    expect(configuration.worker_formatters).to include(%w[html output.html])
  end

  include_examples 'DistribCore configuration'
end

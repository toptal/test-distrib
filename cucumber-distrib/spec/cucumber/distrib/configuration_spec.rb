# frozen_string_literal: true

require 'distrib_core/spec/configuration'

RSpec.describe Cucumber::Distrib::Configuration do
  subject(:configuration) { Cucumber::Distrib.configuration }

  around do |example|
    config = Cucumber::Distrib.instance_variable_get(:@configuration)
    Cucumber::Distrib.instance_variable_set(:@configuration, nil)
    example.run
  ensure
    Cucumber::Distrib.instance_variable_set(:@configuration, config)
  end

  it '#tests_provider' do
    expect(configuration.tests_provider)
      .to eq(::Cucumber::Distrib::Leader::TestsProvider)
  end

  it '#error_handler' do
    expect(configuration.error_handler).to be_a(::Cucumber::Distrib::Leader::ErrorHandler)
  end

  include_examples 'DistribCore configuration'
end

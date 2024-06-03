# frozen_string_literal: true

require 'distrib_core/spec/configuration'

RSpec.describe DistribCore::Configuration do
  subject(:configuration) do
    Class.new do
      include DistribCore::Configuration
    end.new
  end

  it '#tests_provider' do
    expect { configuration.tests_provider }.to raise_error(NotImplementedError)
  end

  it '#error_handler' do
    expect { configuration.error_handler }.to raise_error(NotImplementedError)
  end

  include_examples 'DistribCore configuration'
end

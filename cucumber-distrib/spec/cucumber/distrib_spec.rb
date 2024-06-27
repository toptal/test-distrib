# frozen_string_literal: true

require 'distrib_core/spec/distrib'

RSpec.describe Cucumber::Distrib do
  subject(:root) do
    described_class
  end

  around do |example|
    config = described_class.instance_variable_get(:@configuration)
    described_class.instance_variable_set(:@configuration, nil)
    example.run
  ensure
    described_class.instance_variable_set(:@configuration, config)
  end

  include_examples 'DistribCore root module'
end

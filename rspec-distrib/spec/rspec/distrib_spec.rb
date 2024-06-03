# frozen_string_literal: true

require 'distrib_core/spec/distrib'

RSpec.describe RSpec::Distrib do
  subject(:root) do
    described_class
  end

  around do |example|
    config = described_class.instance_variable_get(:@configuration)
    described_class.instance_variable_set(:@configuration, nil)
    example.run
    described_class.instance_variable_set(:@configuration, config)
  end

  include_examples 'DistribCore root module'
end

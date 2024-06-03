# frozen_string_literal: true

RSpec.describe DistribCore::Leader::QueueBuilder do
  describe '.tests' do
    let(:config) { instance_double(DistribCore::Configuration) }
    let(:provider) { double }

    it 'calls the configured files provider' do
      expect(DistribCore::Configuration).to receive(:current).and_return(config)
      expect(config).to receive(:tests_provider).and_return(provider)
      expect(provider).to receive(:call).and_return([1, 2, 3])

      expect(described_class.tests).to eq [1, 2, 3]
    end
  end
end

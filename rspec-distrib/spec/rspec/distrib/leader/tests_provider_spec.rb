# frozen_string_literal: true

RSpec.describe RSpec::Distrib::Leader::TestsProvider do
  describe '.call' do
    it 'calls Dir.glob' do
      expect(Dir).to receive(:glob).with('spec/**/*_spec.rb')
      described_class.call
    end
  end
end

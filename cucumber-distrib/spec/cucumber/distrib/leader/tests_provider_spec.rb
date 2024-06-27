# frozen_string_literal: true

RSpec.describe Cucumber::Distrib::Leader::TestsProvider do
  describe '.call' do
    it 'calls Dir.glob' do
      expect(Dir).to receive(:glob).with('features/**/*.feature')
      described_class.call
    end
  end
end

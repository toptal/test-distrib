# frozen_string_literal: true

RSpec.describe DistribCore::Metrics do
  let(:now) { Time.now }

  before do
    allow(Time).to receive(:now).and_return(now)
    described_class.instance_variable_set(:@report, nil)
  end

  describe '#queue_exposed' do
    it 'register the current time' do
      described_class.queue_exposed
      expect(described_class.report[:queue_exposed_at]).to eq(now.to_i)
    end
  end

  describe '#test_taken' do
    it 'register the current time for the first spec taken' do
      described_class.test_taken
      allow(Time).to receive(:now).and_return(now + 60)
      described_class.test_taken
      expect(described_class.report[:first_test_taken_at]).to eq(now.to_i)
    end
  end

  describe '#watchdog_repushed' do
    before do
      described_class.watchdog_repushed('foo.rb', 10.0)
      described_class.watchdog_repushed('foo.rb', 11.0)
    end

    it 'increase the counter' do
      expect(described_class.report[:watchdog_repush_count]).to eq(2)
    end

    it 'count timeouts per file' do
      expect(described_class.report[:repushed_files]).to eq('foo.rb' => [10.0, 11.0])
    end
  end
end

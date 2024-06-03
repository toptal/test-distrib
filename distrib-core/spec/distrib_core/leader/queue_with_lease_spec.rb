# frozen_string_literal: true

RSpec.describe DistribCore::Leader::QueueWithLease do
  describe '#lease' do
    it 'leases all entries in FIFO order' do
      queue_with_lease = described_class.new(%i[a b c])
      expect(queue_with_lease.lease).to eq(:c)
      expect(queue_with_lease.lease).to eq(:b)
      expect(queue_with_lease.lease).to eq(:a)
    end

    it 'blocks when nothing left in the queue' do
      entries = []
      queue_with_lease = described_class.new(entries)
      expect(entries).not_to receive(:pop)
      waiting_for_lease = Thread.new do
        queue_with_lease.lease
      end
      sleep(0.5)
      waiting_for_lease.kill
    end

    it 'gets the next one if the element has completed already' do
      queue_with_lease = described_class.new(%i[a b c])
      allow(queue_with_lease).to receive(:completed).and_return(%i[b])
      expect(queue_with_lease.lease).to eq(:c)
      expect(queue_with_lease.lease).to eq(:a)
    end
  end

  describe '#repush' do
    it 'pushes the entry back to the queue' do
      queue_with_lease = described_class.new([:a])
      entry = queue_with_lease.lease
      queue_with_lease.repush(entry)
      expect(queue_with_lease.lease).to eq(:a)
    end
  end

  describe '#release' do
    it 'returns true' do
      queue_with_lease = described_class.new([:a])
      entry = queue_with_lease.lease
      expect(queue_with_lease.release(entry)).to be_truthy
    end

    context 'when already released' do
      it 'returns nil' do
        queue_with_lease = described_class.new([:a])
        entry = queue_with_lease.lease
        queue_with_lease.release(entry)
        expect(queue_with_lease.release(entry)).to be_nil
      end
    end
  end

  describe '#completed?' do
    it 'returns false for not released entry' do
      queue_with_lease = described_class.new([:a])
      expect(queue_with_lease.completed?(:a)).to be false
    end

    it 'returns true for released entry' do
      queue_with_lease = described_class.new([:a])
      queue_with_lease.release(:a)
      expect(queue_with_lease.completed?(:a)).to be true
    end
  end

  describe '#empty?' do
    context 'when initially empty' do
      it 'is empty' do
        queue_with_lease = described_class.new([])
        expect(queue_with_lease).to be_empty
      end
    end

    context 'with some data' do
      it 'is not empty' do
        queue_with_lease = described_class.new([:a])
        expect(queue_with_lease).not_to be_empty
      end
    end

    context 'when leased' do
      it 'is not empty' do
        queue_with_lease = described_class.new([:a])
        _entry = queue_with_lease.lease
        expect(queue_with_lease).not_to be_empty
      end
    end

    context 'when leased and released' do
      it 'is empty' do
        queue_with_lease = described_class.new([:a])
        entry = queue_with_lease.lease
        queue_with_lease.release(entry)
        expect(queue_with_lease).to be_empty
      end
    end

    context 'when something is left on the queue' do
      it 'is not empty' do
        queue_with_lease = described_class.new(%i[a b])
        entry = queue_with_lease.lease
        queue_with_lease.release(entry)
        expect(queue_with_lease).not_to be_empty
      end
    end
  end

  describe '#completed_size' do
    it do
      queue_with_lease = described_class.new(%i[a b c])
      expect(queue_with_lease.completed_size).to eq 0
    end

    it do
      queue_with_lease = described_class.new(%i[a b c])
      queue_with_lease.release(:a)
      queue_with_lease.release(:b)
      expect(queue_with_lease.completed_size).to eq 2
    end
  end

  describe 'leased' do
    subject(:queue_with_lease) { described_class.new(%i[a b]) }

    before do
      allow(Time).to receive(:now).and_return(1)
      queue_with_lease.lease
      allow(Time).to receive(:now).and_return(2)
      queue_with_lease.lease
    end

    describe '#select_leased' do
      it 'returns a hash of entries with times the block returns true' do
        expect(queue_with_lease.select_leased { true }).to eq(b: 1, a: 2)
      end

      it 'returns nothing when the block returns false' do
        expect(queue_with_lease.select_leased { false }).to eq({})
      end

      it 'yields its elements' do
        expect { |b| queue_with_lease.select_leased(&b) }.to yield_successive_args([:b, 1], [:a, 2])
      end

      it 'works on a copy of the original object' do
        selected_before = queue_with_lease.select_leased
        count_before = selected_before.count

        queue_with_lease.repush(:c)
        queue_with_lease.lease

        expect(selected_before.count).to eq(count_before)
      end
    end

    describe '#leased_size' do
      it 'returns the count of leased entries' do
        expect(queue_with_lease.leased_size).to eq(2)
      end
    end
  end
end

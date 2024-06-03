# frozen_string_literal: true

RSpec.describe RSpec::Distrib::Worker do
  describe '.join' do
    subject(:join) { described_class.join(leader_ip) }

    context 'when leader ip is specified' do
      let(:leader_ip) { '127.0.0.1' }

      it 'joins the leader' do
        expect(RSpec::Distrib::Worker::RSpecRunner)
          .to receive(:run_from_leader)
          .with(leader_ip)
          .and_return(0)

        join
      end
    end

    context 'when leader ip is nil' do
      let(:leader_ip) { nil }

      it 'raises an error' do
        expect { join }.to raise_error('Leader IP should be specified')
      end
    end

    context 'when leader ip is empty' do
      let(:leader_ip) { '' }

      it 'raises an error' do
        expect { join }.to raise_error('Leader IP should be specified')
      end
    end
  end
end

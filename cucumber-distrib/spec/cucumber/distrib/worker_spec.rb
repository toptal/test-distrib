# frozen_string_literal: true

RSpec.describe Cucumber::Distrib::Worker do
  describe '.join' do
    subject(:join) { described_class.join(leader_ip) }

    context 'when leader IP is specified' do
      let(:leader_ip) { '127.0.0.1' }

      it 'joins the leader' do
        expect(Cucumber::Distrib::Worker::CucumberRunner)
          .to receive(:run_from_leader)
          .with(leader_ip)
          .and_return(0)

        join
      end
    end

    context 'when leader IP is nil' do
      let(:leader_ip) { nil }

      it 'raises an error' do
        expect { join }.to raise_error('Leader IP should be specified')
      end
    end

    context 'when leader IP is empty' do
      let(:leader_ip) { '' }

      it 'raises an error' do
        expect { join }.to raise_error('Leader IP should be specified')
      end
    end
  end
end

# frozen_string_literal: true

require_relative 'feature_helper'

RSpec.describe 'Aborting worker' do
  include_context 'base pipeline'

  let(:additional_worker_env) { { RSPEC_DISTRIB_ABORT_WORKER: true } }

  specify do
    run_distrib(:passing)

    expect(leader.output).to include 'Leader will stop since worker failed with non_example_exception SystemExit'
    expect(leader.output).to include 'Abort worker in root'
    expect(leader.status).to eq(1)

    expect(worker.output).to include 'Abort worker in root'

    common_leader_checks
  end
end

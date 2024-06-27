require_relative 'feature_helper'

RSpec.describe 'Aborting worker' do
  include_context 'base pipeline'

  let(:additional_worker_env) { { CUCUMBER_DISTRIB_ABORT_WORKER: true } }

  specify do
    run_distrib(:passing, workers_count: 1)

    expect(leader.output).to include 'Leader will stop since worker failed with SystemExit'
    expect(leader.output).to include 'Abort worker in root'
    expect(leader.status).to eq(1)

    expect(worker_outputs).to include match(/Abort worker in root/)

    # common_checks(leader_result, workers_results)
  end
end

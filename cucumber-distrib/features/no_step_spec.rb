require_relative 'feature_helper'

RSpec.describe 'No step features' do
  include_context 'base pipeline'

  specify do
    run_distrib(:no_step, workers_count: 2)

    expect(leader.output).to include '2 scenarios (1 undefined, 1 passed)'
    expect(leader.output).to include '6 steps (1 skipped, 1 undefined, 4 passed)'
    expect(leader.status).to eq(0)

    expect(worker_outputs).to include match(/3 steps \(3 passed\)/)
    expect(worker_outputs).to include match(/3 steps \(1 skipped, 1 undefined, 1 passed\)/)

    # common_checks(leader_result, workers_results)
  end
end

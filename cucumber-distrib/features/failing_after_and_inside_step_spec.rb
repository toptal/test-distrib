require_relative 'feature_helper'

RSpec.describe 'Failing after and inside step' do
  include_context 'base pipeline'

  let(:additional_worker_env) { { CUCUMBER_DISTRIB_FAIL_AFTER_STEP: true } }

  specify do
    skip 'flaky test'

    run_distrib(:failing, workers_count: 2)

    expect(leader.output).to include '3 scenarios (3 failed)'
    expect(leader.output).to include '8 steps (5 skipped, 3 passed)'
    expect(leader.status).to eq(1)

    expect(worker_outputs).to include match(/1 scenario \(1 failed\)/)
    expect(worker_outputs).to include match(/3 steps \(2 skipped, 1 passed\)/)
    expect(worker_outputs).to include match(/2 scenarios \(2 failed\)/)
    expect(worker_outputs).to include match(/5 steps \(3 skipped, 2 passed\)/)

    # common_checks(leader_result, workers_results)
  end
end

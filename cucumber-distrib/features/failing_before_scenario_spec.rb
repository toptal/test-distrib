require_relative 'feature_helper'

RSpec.describe 'Failing in `Before { |scenario| ... }`' do
  include_context 'base pipeline'

  let(:additional_worker_env) { { CUCUMBER_DISTRIB_FAIL_BEFORE: true } }

  specify do
    run_distrib(:passing, workers_count: 2)

    expect(leader.output).to include '2 scenarios (2 failed)'
    expect(leader.output).to include '5 steps (5 skipped)'
    expect(leader.status).to eq(1)

    expect(worker_outputs).to include match(/1 scenario \(1 failed\)/)
    expect(worker_outputs).to include match(/2 steps \(2 skipped\)/)
    expect(worker_outputs).to include match(/1 scenario \(1 failed\)/)
    expect(worker_outputs).to include match(/3 steps \(3 skipped\)/)

    # common_checks(leader_result, workers_results)
  end
end

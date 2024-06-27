require_relative 'feature_helper'

RSpec.describe 'Failing inside step' do
  include_context 'base pipeline'

  specify do
    run_distrib(:failing, workers_count: 2)

    expect(leader.output).to include '3 scenarios (1 failed, 2 passed)'
    expect(leader.output).to include '8 steps (1 failed, 7 passed)'
    expect(leader.status).to eq(1)

    expect(worker_outputs).to include match(/1 scenario \(1 failed\)/)
    expect(worker_outputs).to include match(/3 steps \(1 failed, 2 passed\)/)
    expect(worker_outputs).to include match(/2 scenarios \(2 passed\)/)
    expect(worker_outputs).to include match(/5 steps \(5 passed\)/)

    # common_checks(leader_result, workers_results)
  end
end

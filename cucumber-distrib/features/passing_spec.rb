require_relative 'feature_helper'

RSpec.describe 'Passing features' do
  include_context 'base pipeline'

  specify do
    run_distrib(:passing, workers_count: 2)

    expect(leader.output).to include '2 scenarios (2 passed)'

    expect(leader.output).to include '5 steps (5 passed)'
    expect(leader.status).to eq(0)

    expect(worker_outputs).to include match(/1 scenario \(1 passed\)/)
    expect(worker_outputs).to include match(/2 steps \(2 passed\)/)
    expect(worker_outputs).to include match(/3 steps \(3 passed\)/)

    # common_checks(leader_result, workers_results)
  end
end

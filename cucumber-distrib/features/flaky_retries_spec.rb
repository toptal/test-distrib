require_relative 'feature_helper'

RSpec.describe 'Retries flaky errors' do
  include_context 'base pipeline'

  specify do
    run_distrib(:retries, workers_count: 1)

    expect(leader.output).to include '2 scenarios (2 passed)'
    expect(leader.output).to include '5 steps (5 passed)'
    expect(leader.output).to match(/FORMATTER: retrying_test.*@metadata={:info_from_worker=>"worker_id_or_something"}/)
    expect(leader.status).to eq(0)

    expect(worker_outputs).to include include('Failing on first time')
    expect(worker_outputs).to include include('Wrapping and failing on second time')
    expect(worker_outputs).to include include('Pass on third time')

    # common_checks(leader_result, workers_results)
  end
end

require_relative 'feature_helper'

RSpec.describe 'Failing after configuration' do
  include_context 'base pipeline'

  let(:additional_worker_env) { { CUCUMBER_DISTRIB_FAIL_AFTER_CONFIGURATION: true } }

  specify do
    run_distrib(:passing, workers_count: 2)

    expect(leader.output).to include 'Leader will stop since worker failed with StandardError'
    expect(leader.output).to include 'Fail after configuration'
    expect(leader.status).to eq(1)

    expect(worker_outputs).to include match(/Fail after configuration/)
    expect(worker_outputs).to include match(/StandardError/)

    # common_checks(leader_result, workers_results)
  end
end

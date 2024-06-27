require_relative 'feature_helper'

RSpec.describe 'Timeout when no test picked at all' do
  include_context 'base pipeline'

  specify do
    run_distrib(:passing, workers_count: 0)

    expect(leader.output).to include '2 tests have been enqueued'
    expect(leader.output).to match(
      /Leader has reached the time limit of 5 second\(s\) for the first test being picked from the queue./
    )
    expect(leader.output).to include '0 scenarios'
    expect(leader.status).to eq(1)

    # common_checks(leader_result)
  end
end

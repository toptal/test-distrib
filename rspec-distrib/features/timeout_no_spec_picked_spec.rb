# frozen_string_literal: true

require_relative 'feature_helper'

RSpec.describe 'Timeout when no spec picked at all' do
  include_context 'base pipeline'

  specify do
    started = Time.now
    run_distrib(:passing, workers_count: 0)
    finished = Time.now

    expect(leader.output).to include '2 files have been enqueued'
    expect(leader.output).to include 'Leader has reached the time limit'
    expect(leader.output).to include '0 examples, 0 failures'
    expect(leader.status).to eq(1)

    time_match = leader.output.match(/Finished in (\d+(?:\.\d*)?) seconds/)
    time = time_match[1].to_f
    expect(time).to be_between(2, 3)

    expect(finished - started).to be < 3

    common_leader_checks
  end
end

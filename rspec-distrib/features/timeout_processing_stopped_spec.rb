# frozen_string_literal: true

require_relative 'feature_helper'

RSpec.describe 'Timeout when one spec picked but second did not (worker died)' do
  include_context 'base pipeline'

  specify do
    started = Time.now
    run_distrib(:timeout_processing_stopped)
    finished = Time.now

    expect(leader.output).to include '2 files have been enqueued'
    expect(leader.output).to include 'Workers did not pick tests for too long!'
    expect(leader.output).to include 'Aborting...'
    expect(leader.output).to match(/1 example, 0 failures$/)
    expect(leader.status).to eq(1)

    expect(finished - started).to be < 5

    expect(worker.output).to include 'Foo'
    expect(worker.output).to include 'Wait till timeout'

    common_checks
  end
end

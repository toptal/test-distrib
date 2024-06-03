# frozen_string_literal: true

require_relative 'feature_helper'

RSpec.describe 'Failing in `after(:suite)`' do
  include_context 'base pipeline'

  let(:additional_worker_env) { { RSPEC_DISTRIB_FAIL_AFTER_SUITE: true } }

  specify do
    run_distrib(:passing)

    expect(leader.output).to include '2 files have been enqueued'
    expect(leader.output).to match(/3 examples, 0 failures$/)
    expect(leader.status).to eq(0)

    expect(worker.output).to include 'An error occurred in an `after(:suite)` hook.'
    expect(worker.output).to include '3 examples, 0 failures, 2 errors occurred outside of examples'

    common_checks
  end
end

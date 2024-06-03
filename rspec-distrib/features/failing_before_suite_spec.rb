# frozen_string_literal: true

require_relative 'feature_helper'

RSpec.describe 'Failing in `before(:suite)`' do
  include_context 'base pipeline'

  let(:additional_worker_env) { { RSPEC_DISTRIB_FAIL_BEFORE_SUITE: true } }

  specify do
    run_distrib(:passing)

    expect(leader.output).to include '2 files have been enqueued'
    expect(leader.output).to include 'An error occurred in a `before(:suite)` hook.'
    expect(leader.output).to include '0 examples, 0 failures, 1 error occurred outside of examples'
    expect(leader.status).to eq(1)

    expect(worker.output).to include 'An error occurred in a `before(:suite)` hook.'
    expect(worker.output).to include '0 examples, 0 failures, 1 error occurred outside of examples'

    common_checks
  end
end

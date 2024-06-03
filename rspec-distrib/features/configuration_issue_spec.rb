# frozen_string_literal: true

require_relative 'feature_helper'

RSpec.describe 'Failing during configuration (like loading spec_helper)' do
  include_context 'base pipeline'

  let(:additional_worker_env) { { RSPEC_DISTRIB_FAIL_CONFIGURATION: true } }

  specify do
    run_distrib(:passing)

    expect(leader.output).to include '0 examples, 0 failures, 1 error occurred outside of examples'
    expect(leader.status).to eq(1)

    expect(worker.output).to include '0 examples, 0 failures, 1 error occurred outside of examples'

    common_checks
  end
end

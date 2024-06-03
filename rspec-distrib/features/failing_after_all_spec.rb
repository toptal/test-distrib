# frozen_string_literal: true

require_relative 'feature_helper'

RSpec.describe 'Failing in `after(:all)`' do
  include_context 'base pipeline'

  specify do
    run_distrib(:failing_after_all, workers_count: 2)

    expect(leader.output).to include '2 files have been enqueued'
    expect(leader.output).to include '0 failures, 1 error occurred outside of examples'
    expect(leader.status).to eq(1)

    expect(worker_outputs).to include match(/1 example, 0 failures, 1 error occurred outside of examples/)
    expect(worker_outputs).to include match(/1 example, 0 failures$/)

    common_checks
  end
end

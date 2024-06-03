# frozen_string_literal: true

require_relative 'feature_helper'

RSpec.describe 'Failing in `before(:all)`' do
  include_context 'base pipeline'

  specify do
    run_distrib(:failing_before_all, workers_count: 2)

    expect(leader.output).to include '2 files have been enqueued'
    expect(leader.output).to match(/2 examples, 1 failure$/)
    expect(leader.status).to eq(1)

    expect(worker_outputs).to include match(/1 example, 1 failure$/)
    expect(worker_outputs).to include match(/1 example, 0 failures$/)

    common_checks
  end
end

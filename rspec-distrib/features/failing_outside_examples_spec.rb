# frozen_string_literal: true

require_relative 'feature_helper'

RSpec.describe 'Failing outside examples' do
  include_context 'base pipeline'

  specify do
    run_distrib(:failing_outside_examples, workers_count: 4)

    expect(leader.output).to include '4 files have been enqueued'
    expect(leader.output).to match(/5 examples, 3 failures$/)
    expect(leader.status).to eq(1)

    expect(worker_outputs).to include match(/1 example, 0 failures/)
    expect(worker_outputs).to include match(/2 examples, 1 failure/)
    expect(worker_outputs.grep(/1 example, 1 failure/).count).to eq(2)

    common_checks
  end
end

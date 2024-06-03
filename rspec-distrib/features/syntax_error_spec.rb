# frozen_string_literal: true

require_relative 'feature_helper'

RSpec.describe 'Syntax error in spec file' do
  include_context 'base pipeline'

  specify do
    run_distrib(:syntax_error, workers_count: 2)

    expect(leader.output).to include '2 files have been enqueued'
    expect(leader.output).to include '0 failures, 1 error occurred outside of examples'
    expect(leader.status).to eq(1)

    expect(worker_outputs).to include match(/1 example/)
    expect(worker_outputs).to include match(/1 error/)

    common_checks
  end
end

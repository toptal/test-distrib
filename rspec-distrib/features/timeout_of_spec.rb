# frozen_string_literal: true

require_relative 'feature_helper'

RSpec.describe 'Timeout of spec' do
  include_context 'base pipeline'

  specify do
    run_distrib(:timeout_of_spec, workers_count: 2)

    expect(leader.output).to include '2 files have been enqueued'
    expect(leader.output).to match(/1 example, 0 failures$/)
    expect(leader.output).to match(/Files completed: 1/)
    expect(leader.output).to match(/Files left: 1/)
    expect(leader.status).to eq(1)

    common_checks
  end
end

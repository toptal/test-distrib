# frozen_string_literal: true

require_relative 'feature_helper'

RSpec.describe 'Failing in examples' do
  include_context 'base pipeline'

  specify do
    run_distrib(:failing_inside_examples)

    expect(leader.output).to include '2 files have been enqueued'
    expect(leader.output).to match(/3 examples, 2 failures$/)
    expect(leader.status).to eq(1)

    expect(worker.output).not_to include '0 examples'
    expect(worker.output).to include '2 failures'

    common_checks
  end
end

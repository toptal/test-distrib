# frozen_string_literal: true

require_relative 'feature_helper'

RSpec.describe 'Failing with multiple exceptions' do
  include_context 'base pipeline'

  specify do
    run_distrib(:failing_multiple_exceptions)

    expect(leader.output).to include '3 files have been enqueued'
    expect(leader.output).to include '0 failures and 2 other errors'
    expect(leader.output).to match(/StandardError: 1\n\n\W*AND\n\n\W*StandardError: 2/)
    expect(leader.output).to match(/3 examples, 1 failure$/)
    expect(leader.status).to eq(1)

    expect(worker.output).to include '1 Pass spec'
    expect(worker.output).to include '2 Fail spec'
    expect(worker.output).to include '3 Pass spec'
    expect(worker.output).to match(/3 examples, 1 failure$/)

    common_checks
  end
end

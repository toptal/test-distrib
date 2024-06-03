# frozen_string_literal: true

require_relative 'feature_helper'

RSpec.describe 'Flaky retries' do
  include_context 'base pipeline'

  specify do
    run_distrib(:flaky_retries)

    expect(leader.output).to include '2 files have been enqueued'
    expect(leader.output).to match(/2 examples, 0 failures$/)
    expect(leader.status).to eq(0)

    expect(worker.output).to include 'Failing on first time'
    expect(worker.output).to include 'Wrapping and failing on second time'
    expect(worker.output).to include 'Pass on third time'
    expect(worker.output).to match(/Foo.*Zap.*Foo.*Foo/m)

    common_checks
  end
end

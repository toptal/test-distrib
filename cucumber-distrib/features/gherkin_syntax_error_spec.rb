require_relative 'feature_helper'

RSpec.describe 'Gherkin syntax error' do
  include_context 'base pipeline'

  # rubocop:disable Layout/LineLength
  specify do
    run_distrib(:gherkin_syntax_error, workers_count: 1)

    expect(leader.output).to include '1 scenario (1 passed)'
    expect(leader.output).to include '3 steps (3 passed)'
    expect(leader.output).to match %r{Leader will stop since worker failed with Cucumber::Core::Gherkin::ParseError on test.*fixtures/cucumber/features/gherkin_syntax_error/1.feature}
    expect(leader.status).to eq(1)

    expect(worker_outputs).to include match(%r{fixtures/cucumber/features/gherkin_syntax_error/1.feature.*Cucumber::Core::Gherkin::ParseError})

    # common_checks(leader_result, workers_results)
  end
  # rubocop:enable Layout/LineLength
end

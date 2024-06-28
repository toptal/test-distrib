require_relative 'feature_helper'

RSpec.describe 'Ruby syntax error in a file required by step' do
  include_context 'base pipeline'

  specify do
    run_distrib(:ruby_syntax_error_in_step, workers_count: 2)

    expect(leader.output).to include '2 scenarios (1 failed, 1 passed)'
    expect(leader.output).to include '4 steps (1 failed, 3 passed)'
    expect(leader.output).to match %r{lib/file_with_syntax_error.rb.*SyntaxError}
    expect(leader.status).to eq(1)

    expect(worker_outputs).to include include('1 scenario (1 passed)')
    expect(worker_outputs).to include include('3 steps (3 passed)')
    expect(worker_outputs).to include include('1 scenario (1 failed)')
    expect(worker_outputs).to include include('1 step (1 failed)')

    # common_checks(leader_result, workers_results)
  end
end

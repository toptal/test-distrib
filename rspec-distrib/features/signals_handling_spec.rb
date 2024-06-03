# frozen_string_literal: true

require_relative 'feature_helper'

RSpec.describe 'Signals handling' do
  include_context 'base pipeline'

  def with_delay
    sleep(1.5) # let a process to load
    yield
    sleep(0.1) # let a process to react
  end

  it 'finishes current file and exits' do
    run_distrib(:signals_handling) do |(_, worker)|
      with_delay { Process.kill('INT', worker.pid) }
    end

    expect(worker.output).to include('Received INT')
    expect(worker.status).to eq(2)

    expect(leader.output).to include('1 example, 0 failures')
    expect(leader.output).to include('Build succeeded. Files processed: 1')
    expect(leader.status).to eq(0)

    common_checks
  end

  it 'exits a worker immediately' do
    run_distrib(:signals_handling) do |(_, worker)|
      with_delay do
        Process.kill('INT', worker.pid)
        sleep(0.1)
        Process.kill('INT', worker.pid)
      end
    end

    expect(worker.output).to include('Received INT')
    expect(worker.output).to include('Received second SIGINT')
    expect(worker.status).to eq(2)

    expect(leader.output).to include('0 examples, 0 failures')
    expect(leader.output).to include('Build failed')
    expect(leader.output).to include('Files left: 1')
    expect(leader.status).to eq(1)

    common_checks
  end

  it 'does not send results to the leader' do
    run_distrib(:signals_handling) do |(_, worker)|
      with_delay { Process.kill('TERM', worker.pid) }
    end

    expect(worker.output).to include('Received TERM')
    expect(worker.status).to eq(15)

    expect(leader.output).to include('Build failed')
    expect(leader.output).to include('Files left: 1')
    expect(leader.output).to include(' 1 tests not executed')
    expect(leader.status).to eq(1)

    common_checks
  end

  it 'exits leader properly' do
    run_distrib(:signals_handling, workers_count: 0) do |(leader, _)|
      with_delay do
        Process.kill('TERM', leader.pid)
      end
    end

    expect(leader.output).to include('Build failed')
    expect(leader.output).to include('Files left: 1')
    expect(leader.status).to eq(15)

    common_leader_checks
  end
end

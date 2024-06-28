require_relative 'feature_helper'

RSpec.describe 'Signals handling' do
  include_context 'base pipeline'

  def with_delay
    sleep(2.0) # let a process to load
    yield
    sleep(0.1) # let a process to react
  end

  it 'finishes current file and exits' do
    skip 'flaky test'

    run_distrib(:signals_handling, workers_count: 1) do |(_, worker)|
      with_delay { Process.kill('INT', worker.pid) }
    end

    expect(workers[0].output).to include('Received INT')
    expect(workers[0].status).to eq(2)

    expect(leader.output).to include('1 scenario (1 passed)')
    expect(leader.output).to include('Build succeeded. Tests processed: 1')
    expect(leader.status).to eq(0)

    # common_checks(leader_output, worker_outputs)
  end

  it 'exits a worker immediately' do
    skip 'flaky test'

    run_distrib(:signals_handling, workers_count: 1) do |(_, worker)|
      with_delay do
        Process.kill('INT', worker.pid)
        sleep(0.1)
        Process.kill('INT', worker.pid)
      end
    end

    expect(workers[0].output).to include('Received INT')
    expect(workers[0].output).to include('Received second SIGINT')
    expect(workers[0].status).to eq(2)

    expect(leader.output).to include('0 scenarios')
    expect(leader.output).to include('Build failed')
    expect(leader.output).to include('Tests left: 1')
    expect(leader.output).to include(' 1 tests not executed')
    expect(leader.status).to eq(1)

    # common_checks(leader.output, worker_outputs)
  end

  it 'does not send results to the leader' do
    run_distrib(:signals_handling, workers_count: 1) do |(_, worker)|
      with_delay { Process.kill('TERM', worker.pid) }
    end

    expect(workers[0].output).to include('Received TERM')
    expect(workers[0].status).to eq(15)

    expect(leader.output).to include('Build failed')
    expect(leader.output).to include('Tests left: 1')
    expect(leader.output).to include(' 1 tests not executed')
    expect(leader.status).to eq(1)

    # common_checks(leader.output, worker_outputs)
  end

  it 'exits leader properly' do
    run_distrib(:signals_handling, workers_count: 0) do |(leader, _)|
      with_delay do
        Process.kill('TERM', leader.pid)
      end
    end

    expect(leader.output).to include('Build failed')
    expect(leader.output).to include('Tests left: 1')
    expect(leader.status).to eq(15)

    # common_checks(leader.output)
  end
end

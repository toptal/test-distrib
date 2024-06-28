# frozen_string_literal: true

require 'tempfile'

# Class representing the result of child process execution.
# It is used to inspect output as well as exit status of
# cucumber-distrib leader or worker processes.
class Result
  attr_accessor :output, :pid, :status, :type, :file

  def initialize(file:, pid:, type:, output: nil, status: nil)
    @file = file
    @output = output
    @pid = pid
    @status = status
    @type = type
  end
end

shared_context 'base pipeline' do
  let(:features) { Pathname(__dir__).join('..', '..') }
  let(:fixtures) { features.join('fixtures') }
  let(:cucumber) { fixtures.join('cucumber') }
  let!(:leader_output) { Tempfile.new('leader') }
  let(:additional_worker_env) { {} }

  before do
    @leader = nil
    @workers = []
  end

  attr_reader :leader, :workers

  def worker_outputs
    @workers.map(&:output)
  end

  def worker
    raise 'You are asking for one worker when there are many' if workers.count > 1

    workers.first
  end

  def run_distrib(folder_name, workers_count: 1) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
    results = {}

    folder_path = cucumber.join('features', folder_name.to_s)
    raise(ArgumentError, "Folder #{folder_path} doesn't exist") unless File.directory?(folder_path)

    worker_env = additional_worker_env.each_with_object({}) { |(k, v), acc| acc[k.to_s] = v.to_s }
    worker_env['CUCUMBER_DISTRIB_MULTIPLE_WORKERS'] = 'true' if workers_count > 1

    workers_count.times do
      spawn_process(:worker, worker_env).tap { |res| results[res.pid] = res }
    end

    sleep(1) if workers_count > 1 # allow workers to start

    spawn_process(:leader, 'CUCUMBER_DISTRIB_FOLDER' => folder_name.to_s).tap { |res| results[res.pid] = res }

    yield results.values.sort_by(&:type) if block_given?

    statuses = Process.waitall

    statuses.each do |_, status| # rubocop:disable Style/HashEachMethods because it is an array of arrays
      results[status.pid].status = status.exited? ? status.exitstatus : status.to_i
      results[status.pid].output = results[status.pid].file.read
    end

    results.values.sort_by(&:type).tap do |res| # leader first, than workers
      @leader, *@workers = res
    end
  ensure
    results.each do |_, result| # rubocop:disable Style/HashEachMethods because it is an array of arrays
      result.file.close
      result.file.unlink
    end
  end

  def spawn_process(type, env)
    file = Tempfile.new(type.to_s)
    distrib_command = 'bundle exec cucumber-distrib'
    cmd = type == :leader ? 'start' : 'join 127.0.0.1'
    pid = spawn(env, [distrib_command, cmd].join(' '), %i[out err] => file.path.to_s, chdir: cucumber)
    Result.new(pid:, file:, type:)
  end

  def common_checks(leader_result, workers_results = [])
    common_leader_checks(leader_result)

    common_worker_checks(
      workers_results.is_a?(Array) ? workers_results : [workers_results],
      leader_result.match(/Using seed (\d+)/)[1]
    )
  end

  def common_leader_checks(leader_result)
    expect(leader_result).to include 'Using seed'
    expect(leader_result).to include 'Finished in'
    # expect(leader_result).not_to include 'Unable to read failed line'
    expect(leader_result).to include 'on_finish called'

    check_formatter(
      leader_result,
      leader_result.match(/Using seed (\d+)/)[1],
      common_formatter_events
    )
  end

  def common_worker_checks(workers_results, leader_seed)
    workers_results.each do |worker_result|
      expect(worker_result).to include "Randomized with seed #{leader_seed}"
      expect(worker_result).to include 'Finished in'
      expect(worker_result).not_to include 'has already been initialized with'
    end

    check_formatter(workers_results, leader_seed, common_formatter_events)
  end

  def check_formatter(results, seed, *events)
    results = results.is_a?(Array) ? results : [results]
    events = events.flatten

    results.each do |result|
      expect(result).to match(/FORMATTER: seed.*seed=#{seed}/)
      events.each do |event|
        expect(result).to include "FORMATTER: #{event}"
      end
    end
  end
end

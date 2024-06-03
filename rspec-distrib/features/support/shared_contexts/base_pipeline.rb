# frozen_string_literal: true

require 'tempfile'

# Class representing the result of child process execution.
# It is used to inspect output as well as exit status of
# rspec-distrib leader or worker processes
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
  let(:specs) { fixtures.join('specs') }
  let!(:leader_output) { Tempfile.new('leader') }
  let(:additional_worker_env) { {} }
  let(:common_formatter_events) do
    %i[seed start stop start_dump dump_pending
       dump_failures deprecation_summary dump_summary close]
  end

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

  def run_distrib(folder_name, workers_count: 1) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    results = {}

    folder_path = specs.join(folder_name.to_s)
    raise(ArgumentError, "Folder #{folder_path} doesn't exist") unless File.directory?(folder_path)

    worker_env = additional_worker_env.each_with_object({}) { |(k, v), acc| acc[k.to_s] = v.to_s }
    worker_env['RSPEC_DISTRIB_MULTIPLE_WORKERS'] = 'true' if workers_count > 1

    workers_count.times do
      spawn_process(:worker, worker_env).tap { |res| results[res.pid] = res }
    end

    sleep(1) if workers_count > 1 # allow workers to start

    spawn_process(:leader, 'RSPEC_DISTRIB_FOLDER' => folder_name.to_s).tap { |res| results[res.pid] = res }

    yield results.values.sort_by(&:type) if block_given?

    statuses = Process.waitall

    statuses.each do |_, status| # rubocop:disable Style/HashEachMethods
      results[status.pid].status = status.exited? ? status.exitstatus : status.to_i
      results[status.pid].output = results[status.pid].file.read
    end

    results.values.sort_by(&:type).tap do |res| # leader first, than workers
      @leader, *@workers = res
    end
  ensure
    results.each do |_, result| # rubocop:disable Style/HashEachMethods
      result.file.close
      result.file.unlink
    end
  end

  def spawn_process(type, env)
    file = Tempfile.new(type.to_s)
    distrib_command = 'bundle exec rspec-distrib'
    cmd = type == :leader ? 'start' : 'join 127.0.0.1'
    pid = spawn(env, [distrib_command, cmd].join(' '), %i[out err] => file.path.to_s, chdir: specs)
    Result.new(pid:, file:, type:)
  end

  def common_checks
    common_leader_checks
    common_worker_checks
  end

  def common_leader_checks # rubocop:disable Metrics/AbcSize
    expect(leader.output).to include 'Using seed'
    expect(leader.output).to include 'Finished in'
    # expect(leader.output).not_to include 'Unable to read failed line'
    expect(leader.output).to include 'on_finish called'

    check_formatter(
      leader.output,
      leader.output.match(/Using seed (\d+)/)[1],
      common_formatter_events
    )
  end

  def common_worker_checks # rubocop:disable Metrics/AbcSize
    leader_seed = leader.output.match(/Using seed (\d+)/)[1]
    worker_outputs.each do |output|
      expect(output).to include "Randomized with seed #{leader_seed}"
      expect(output).to include 'Finished in'
      expect(output).not_to include 'has already been initialized with'
    end

    check_formatter(worker_outputs, leader_seed, common_formatter_events)
  end

  def check_formatter(results, seed, *events)
    results = [results] unless results.is_a?(Array)
    events = events.flatten

    results.each do |result|
      expect(result).to match(/FORMATTER: seed.*seed=#{seed}/)
      events.each do |event|
        expect(result).to include "FORMATTER: #{event}"
      end
    end
  end
end

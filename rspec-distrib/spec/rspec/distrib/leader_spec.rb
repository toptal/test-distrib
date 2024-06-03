# frozen_string_literal: true

RSpec.describe RSpec::Distrib::Leader do
  subject(:leader) { described_class.new(queue, reporter, 123) }

  let(:reporter) { instance_double(RSpec::Distrib::Leader::Reporter, 'reporter') }

  before do
    skip "Leader specs can't run in distrib mode" if already_running_in_distrib?
  end

  # Some specs try to start a thread with a leader, and loop forever on the main
  # thread waiting to become available. If you run those tests inside rspec-distrib itself
  # they get hung up forever because the port for the leader is taken.
  #
  # Other tests stub stuff on DRb, which causes issues for the operation of the running leader
  def already_running_in_distrib?
    RSpec::Distrib.kind # This is only set when running in distrib. Otherwise it raises
  rescue StandardError
    false
  end

  describe '.start_service' do
    it do
      seed = 123
      file_paths = instance_double(Array, 'file_paths', length: 10_000, count: 10_000)
      queue = instance_double(DistribCore::Leader::QueueWithLease, 'queue_with_lease')
      allow(queue).to receive_messages(size: 0, completed_size: file_paths.length)

      expect(DistribCore::Leader::QueueBuilder).to receive(:tests).and_return(file_paths)
      expect(DistribCore::Leader::QueueWithLease)
        .to receive(:new).with(file_paths).and_return(queue)

      expect(RSpec::Distrib::Leader::Reporter).to receive(:new).and_return(reporter)

      leader = instance_double(described_class, 'leader')
      expect(described_class).to receive(:new).with(queue, reporter, seed).and_return(leader)

      watchdog = instance_double(DistribCore::Leader::Watchdog, 'watchdog')
      expect(leader).to receive(:non_example_exception)
      expect(DistribCore::Leader::Watchdog).to receive(:new).with(queue).and_return(watchdog)
      expect(watchdog).to receive(:start)
      expect(watchdog).to receive(:failed?).and_return(false)

      expect(DRb).to receive(:start_service).with('druby://0.0.0.0:8787', leader, instance_of(Hash))
      expect(DRb).to receive_message_chain(:thread, :join) # rubocop:disable RSpec/MessageChain

      expect(reporter).to receive(:finish)
      expect(reporter).to receive(:failures?)

      allow(RSpec::Distrib.configuration.broadcaster).to receive(:info)
      expect(RSpec::Distrib.configuration.broadcaster).to receive(:info).with('10000 files have been enqueued')
      described_class.start_service(seed)
    end

    describe 'exit codes' do
      include RSpec::Support::InSubProcess

      it 'exits with 1 on non_example_exception' do
        in_sub_process_if_possible(false) do
          allow(STDOUT).to receive(:puts)

          leader_thread = Thread.new do
            expect { described_class.start_service }.to raise_error(SystemExit) do |error|
              expect(error.status).to eq(1)
            end
          end

          loop do
            sleep 0.1
            break if DRb.current_server
          rescue DRb::DRbServerNotFound
            retry
          end

          remote_leader = DRbObject.new_with_uri(RSpec::Distrib::Leader::DRB_SERVER_URL % 'localhost')
          error = instance_double(RSpec::Distrib::ExecutionResults::Exception,
                                  original_class: 'StandardError',
                                  cause: nil,
                                  message: 'foo',
                                  backtrace: [])
          remote_leader.notify_non_example_exception(error, '')
          leader_thread.join
        end
      end
    end
  end

  describe '#next_file_to_run' do
    let(:queue) { DistribCore::Leader::QueueWithLease.new(file_paths) }

    context 'with a spec file in the queue' do
      let(:file_paths) { ['file_path'] }

      it 'returns a spec from the top of the queue' do
        expect(leader.next_file_to_run).to eq('file_path')
      end
    end

    context 'with a couple of spec files in the queue' do
      let(:file_paths) { %w[file_path another_file_path] }

      it 'does not return the same spec when called twice' do
        expect(leader.next_file_to_run).to eq('another_file_path')
        expect(leader.next_file_to_run).to eq('file_path')
      end
    end
  end

  describe '#report_file' do
    let(:queue) { instance_double(DistribCore::Leader::QueueWithLease, size: 1, completed_size: 1) }
    let(:file_path) { 'file_path' }
    let(:example_groups) { [instance_double(RSpec::Distrib::ExampleGroup)] }

    before { allow(RSpec::Distrib::Leader::Reporter).to receive(:new).and_return(reporter) }

    context 'when spec is not released (not reported by other worker)' do
      it 'delegates to the reporter' do
        allow(queue).to receive(:completed?).with(file_path).and_return(false)
        allow(queue).to receive(:release).with(file_path).and_return(true)
        expect(reporter).to receive(:report).with(example_groups.first)
        leader.report_file(file_path, example_groups)
      end
    end

    context 'when spec is released (already reported by other worker)' do
      it 'does not delegate to the reporter' do
        allow(queue).to receive(:completed?).with(file_path).and_return(true)
        allow(queue).to receive(:release).with(file_path).and_return(false)
        expect(reporter).not_to receive(:report)
        leader.report_file(file_path, example_groups)
      end
    end

    context 'when spec failed but should be retried' do
      it 'placed back to queue and notify reporter' do
        spec = './some_spec.rb'
        allow(RSpec::Distrib.configuration.error_handler)
          .to receive(:retry_test?).with(spec, example_groups, nil).and_return(true)
        allow(queue).to receive(:completed?).with(spec).and_return(false)
        expect(queue).to receive(:repush).with(spec)
        expect(reporter).to receive(:report).with(example_groups.first, will_be_retried: true)

        leader.report_file(spec, example_groups)
      end
    end
  end

  describe '#seed' do
    let(:queue) { DistribCore::Leader::QueueWithLease.new([]) }

    it 'returns constant numerical seed' do
      expect(leader.seed)
        .to eq(leader.seed)
        .and be_between(0, 65_535)
    end
  end

  describe '#notify_non_example_exception' do
    let(:exception) do
      instance_double(RSpec::Distrib::ExecutionResults::Exception,
                      original_class: 'FooError',
                      cause: nil,
                      message: 'foo',
                      backtrace: [])
    end
    let(:context_description) { '' }
    let(:queue) { DistribCore::Leader::QueueWithLease.new(%i[a b c]) }

    it 'notifies reporter and stops the service' do
      expect(reporter).to receive(:notify_non_example_exception)
        .with(exception, context_description)
      server = instance_double(DRb::DRbServer)
      expect(DRb).to receive(:current_server).and_return(server)
      expect(server).to receive(:stop_service)

      leader.notify_non_example_exception(exception, context_description)
    end

    context 'when failure should be ignored' do
      it 'ignores the failure' do
        allow(RSpec::Distrib.configuration.error_handler)
          .to receive(:ignore_worker_failure?).with(exception).and_return(true)

        expect(reporter).not_to receive(:notify_non_example_exception)
        expect(DRb).not_to receive(:current_server)

        leader.notify_non_example_exception(exception, context_description)
      end
    end
  end

  describe '#report_worker_configuration_error' do
    let(:exception) do
      instance_double(RSpec::Distrib::ExecutionResults::Exception,
                      original_class: 'FooError',
                      cause: nil,
                      message: 'foo',
                      backtrace: [])
    end
    let(:queue) { DistribCore::Leader::QueueWithLease.new(%i[a b c]) }

    it 'stops the service' do
      server = instance_double(DRb::DRbServer)
      expect(DRb).to receive(:current_server).and_return(server)
      expect(server).to receive(:stop_service)

      leader.report_worker_configuration_error(exception)
    end

    context 'when failure should be ignored' do
      it 'ignores the failure' do
        allow(RSpec::Distrib.configuration.error_handler)
          .to receive(:ignore_worker_failure?).with(exception).and_return(true)

        expect(DRb).not_to receive(:current_server)

        leader.report_worker_configuration_error(exception)
      end
    end
  end
end

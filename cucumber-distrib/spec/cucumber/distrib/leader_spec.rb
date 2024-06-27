# frozen_string_literal: true

require 'cucumber/core/test/location'

RSpec.describe Cucumber::Distrib::Leader do
  subject(:leader) { described_class.new(queue, runtime, reporter, 123) }

  let(:runtime) { instance_double(Cucumber::Runtime) }
  let(:reporter) { instance_double(Cucumber::Distrib::Leader::Reporter, 'reporter') }

  before do
    allow(reporter).to receive(:report_test_run_started)
  end

  describe '.start_service' do
    let(:paths) { ['features/fixtures/cucumber/features/passing/'] }
    let(:provided_tests) { ['features/fixtures/cucumber/features/passing/1.feature:4'] }

    it do
      queue = instance_double(DistribCore::Leader::QueueWithLease, 'queue_with_lease')
      allow(queue).to receive_messages(size: 0, completed_size: provided_tests.length)

      expect(DistribCore::Leader::QueueBuilder).to receive(:tests).and_return(provided_tests)
      expect(DistribCore::Leader::QueueWithLease)
        .to receive(:new).with(provided_tests).and_return(queue)

      profiles = %w[profile1 profile2]
      cli = instance_double(Cucumber::Cli::Main, configuration: { profiles: })

      expect(Cucumber::Cli::Main).to receive(:new).with([
                                                          '--profile', profiles[0], '--profile', profiles[1]
                                                        ]).and_return(cli).twice

      event_bus_local = Cucumber::Core::EventBus.new

      expect(Cucumber::Core::EventBus).to receive(:new)
        .with(no_args)
        .and_return(event_bus_local)
        .once

      event_bus = instance_double(Cucumber::Core::EventBus)

      expect(Cucumber::Core::EventBus).to receive(:new)
        .with(Cucumber::Distrib::Events.leader_registry)
        .and_return(event_bus)

      runtime_local = instance_double(Cucumber::Runtime, features: [], filters: [])

      expect(runtime_local).to receive(:compile) do
        event = Cucumber::Core::Events::TestCaseStarted.new(
          instance_double(
            Cucumber::Core::Test::Case,
            location: instance_double(
              Cucumber::Core::Test::Location::Precise,
              to_s: 'features/fixtures/cucumber/features/passing/1.feature:4'
            )
          )
        )

        event_bus_local.broadcast(event)
      end

      runtime = instance_double(Cucumber::Runtime, failure?: nil)

      expect(runtime).to receive(:visitor=).with('report')
      expect(runtime).to receive(:report).and_return('report')

      expect(Cucumber::Runtime).to receive(:new) do |hash|
        expect(hash).to include(
          dry_run: true,
          paths:,
          event_bus: event_bus_local,
          profiles:
        )

        runtime_local
      end.once

      expect(Cucumber::Runtime).to receive(:new) do |hash|
        expect(hash).to include(event_bus:, profiles:)
        runtime
      end

      expect(Cucumber::Distrib::Leader::Reporter).to receive(:new).with(runtime).and_return(reporter)

      leader = instance_double(described_class, 'leader')
      expect(described_class).to receive(:new).with(queue, profiles, reporter, runtime).and_return(leader)

      watchdog = instance_double(DistribCore::Leader::Watchdog, 'watchdog')
      expect(leader).to receive(:non_example_exception)
      expect(DistribCore::Leader::Watchdog).to receive(:new).with(queue).and_return(watchdog)
      expect(watchdog).to receive(:start)
      expect(watchdog).to receive(:failed?).and_return(false)

      # cover meta event broadcasting:
      #   runtime.configuration.event_bus.broadcast(meta_event)
      configuration = instance_double(Cucumber::Configuration, event_bus:)
      expect(event_bus).to receive(:broadcast).with(instance_of(Cucumber::Distrib::Events::Envelope))
      expect(runtime).to receive(:configuration).and_return(configuration)

      expect(DRb).to receive(:start_service).with('druby://0.0.0.0:8788', leader, instance_of(Hash))
      expect(DRb).to receive_message_chain(:thread, :join) # rubocop:disable RSpec/MessageChain

      expect(reporter).to receive(:report_test_run_finished)

      allow(Cucumber::Distrib.configuration.broadcaster).to receive(:info)
      expect(Cucumber::Distrib.configuration.broadcaster).to receive(:info)
        .with('1 tests have been enqueued')

      described_class.start_service(profiles:, paths:)
    end

    describe '.filter_provided_tests' do
      subject(:filter_provided_tests) do
        described_class.filter_provided_tests(tests:, profiles:, paths:)
      end

      let(:tests) do
        [
          'features/fixtures/cucumber/features/passing/1.feature:5',
          'features/fixtures/cucumber/features/failing/1.feature:5'
        ]
      end
      let(:profiles) { ['filtered'] }
      let(:paths) { ['features/fixtures/cucumber/features/passing/', 'features/fixtures/cucumber/features/failing/'] }

      it 'returns the filtered tests for the given profile' do
        cli = instance_double(Cucumber::Cli::Main, configuration: { profiles:, tag_limits: [] })

        expect(Cucumber::Cli::Main).to receive(:new).with(['--profile', profiles[0]]).and_return(cli).once

        expect(filter_provided_tests).to eq(['features/fixtures/cucumber/features/passing/1.feature:5'])
      end
    end

    describe 'exit codes' do
      include RSpec::Support::InSubProcess

      let(:paths) { ['features/fixtures/cucumber/features/passing/'] }
      let(:provided_test) { ['features/fixtures/cucumber/features/passing/1.feature:4'] }

      it 'exits with 1 on non_example_exception' do
        skip 'flaky test'

        in_sub_process_if_possible do
          expect(DistribCore::Leader::QueueBuilder).to receive(:tests).and_return(provided_test)

          leader_thread = Thread.new do
            expect { described_class.start_service(profiles: [], paths:) }.to raise_error(SystemExit) do |error|
              expect(error.status).to eq(1)
            end
          end

          loop do
            sleep 0.1
            expect(leader_thread).to be_alive
            break if DRb.current_server
          rescue DRb::DRbServerNotFound
            retry
          end

          remote_leader = DRbObject.new_with_uri(Cucumber::Distrib::Leader::DRB_SERVER_URL % 'localhost')

          error = instance_double(
            Cucumber::Distrib::Events::Exception,
            original_class: 'FooError',
            cause: nil,
            message: 'Foo',
            backtrace: []
          )

          remote_leader.report_test('', [], error)
          leader_thread.join
          nil
        end
      end
    end
  end

  describe '#next_test_to_run' do
    let(:queue) { DistribCore::Leader::QueueWithLease.new(provided_tests) }

    context 'with a file in the queue' do
      let(:provided_tests) { ['file_path'] }

      it 'returns a file from the top of the queue' do
        expect(reporter).to receive(:report_test_run_started)
        expect(leader.next_test_to_run).to eq('file_path')
      end
    end

    context 'with a couple of files in the queue' do
      let(:provided_tests) { %w[file_path another_file_path] }

      it 'does not return the same file when called twice' do
        expect(reporter).to receive(:report_test_run_started).once
        expect(leader.next_test_to_run).to eq('another_file_path')
        expect(leader.next_test_to_run).to eq('file_path')
      end
    end
  end

  describe '#report_test' do
    let(:queue) { instance_double(DistribCore::Leader::QueueWithLease, size: 1, completed_size: 1) }
    let(:file_path) { 'file_path' }
    let(:events) { [instance_double(Cucumber::Distrib::Events::TestCaseFinished)] }

    before { allow(Cucumber::Distrib::Leader::Reporter).to receive(:new).and_return(reporter) }

    context 'when test is not released (not reported by other worker)' do
      it 'delegates to the reporter' do
        allow(queue).to receive(:completed?).with(file_path).and_return(false)
        allow(queue).to receive(:release).with(file_path).and_return(true)
        expect(reporter).to receive(:report_events).with(events)
        result = leader.report_test(file_path, events)
        expect(result).to eq(
          will_be_retried: false,
          events:
        )
      end
    end

    context 'when test is released (already reported by other worker)' do
      it 'does not delegate to the reporter' do
        allow(queue).to receive(:completed?).with(file_path).and_return(true)
        allow(queue).to receive(:release).with(file_path).and_return(false)
        result = leader.report_test(file_path, events)
        expect(result).to be_nil
      end
    end

    context 'when test failed but should be retried' do
      it 'placed back to queue and notify reporter' do
        exception = Cucumber::Distrib::Events::Exception.new(StandardError.new('Oops'))

        allow(Cucumber::Distrib.configuration.error_handler)
          .to receive(:retry_test?).with(file_path, events, exception).and_return(true)
        allow(queue).to receive(:completed?).with(file_path).and_return(false)
        allow(events.first).to receive(:is_a?)
          .with(Cucumber::Distrib::Events::TestCaseFinished)
          .and_return(true)

        expect(queue).to receive(:repush).with(file_path)
        expect(reporter).to receive(:report_retrying_test).with(events.first)

        result = leader.report_test(file_path, events, exception)
        expect(result).to eq(
          will_be_retried: true,
          events:
        )
      end
    end

    context 'when test failed and retries exceed' do
      it 'reports failure' do
        allow(Cucumber::Distrib.configuration.error_handler)
          .to receive(:retry_test?).with(file_path, events, nil).and_return(false)
        allow(queue).to receive(:completed?).with(file_path).and_return(false)
        expect(queue).to receive(:release).with(file_path)
        expect(reporter).to receive(:report_events).with(events)
        result = leader.report_test(file_path, events)
        expect(result).to eq(
          will_be_retried: false,
          events:
        )
      end
    end

    context 'when worker failed outside test' do
      let(:original_error) { StandardError.new('BOOM!') }
      let(:exception) { Cucumber::Distrib::Events::Exception.new(original_error) }

      let(:drb_server) { instance_double(DRb::DRbServer) }

      before do
        allow(Cucumber::Distrib.configuration.error_handler)
          .to receive(:retry_test?).and_return(false)
        allow(DRb).to receive(:current_server).and_return(drb_server)
        allow(queue).to receive(:release)
        allow(queue).to receive(:completed?)
        allow(reporter).to receive(:report_events)
      end

      specify do
        expect(drb_server).to receive(:stop_service)

        leader.report_test(file_path, events, exception)
      end

      context 'when the failure is known due to Scenario Outlines' do
        let(:original_error) do
          NoMethodError.new("undefined method `after_test_case' for nil:NilClass")
        end

        specify do
          expect(drb_server).not_to receive(:stop_service)

          leader.report_test(file_path, events, exception)
        end
      end
    end
  end

  describe '#report_worker_configuration_error' do
    let(:exception) do
      instance_double(Cucumber::Distrib::Events::Exception,
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
        allow(Cucumber::Distrib.configuration.error_handler)
          .to receive(:ignore_worker_failure?).with(exception).and_return(true)

        expect(DRb).not_to receive(:current_server)

        leader.report_worker_configuration_error(exception)
      end
    end
  end
end

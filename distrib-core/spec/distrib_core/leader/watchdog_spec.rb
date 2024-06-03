# frozen_string_literal: true

RSpec.describe DistribCore::Leader::Watchdog do
  # Runs watchdog in the current thread
  def start_watchdog_in_the_same_thread
    allow(Thread).to receive(:new).and_wrap_original do |*, &block|
      block.call
    end

    watchdog.start
  end

  subject(:watchdog) { described_class.new(queue) }

  before do
    allow(Kernel).to receive(:sleep)
    allow(DRb).to receive_message_chain(:current_server, :stop_service) # rubocop:disable RSpec/MessageChain
  end

  let!(:configuration) do
    config = Class.new do |klass|
      klass.include DistribCore::Configuration
    end.new

    config.instance_variable_set(:@broadcaster, broadcaster)

    config
  end

  let(:broadcaster) { Logger.new(nil) }

  after do
    DistribCore::Configuration.instance_variable_set(:@current, nil)
  end

  def stub_leased(leased)
    allow(queue).to receive_messages(select_leased: leased, leased_size: leased.size)
  end

  describe 'pulling back of timed out entries' do
    let(:queue) { DistribCore::Leader::QueueWithLease.new(%i[one two]) }

    before do
      allow(queue).to receive(:empty?).and_return(true)
      allow(broadcaster).to receive(:info)
      allow(broadcaster).to receive(:warn)
    end

    context 'with no timed out entries' do
      it 'does not pull anything' do
        stub_leased({})
        expect(queue).not_to receive(:repush)

        start_watchdog_in_the_same_thread

        expect(broadcaster).not_to have_received(:warn)
      end
    end

    context 'with timed out entries' do
      it 'pulls back timed out entries' do
        configuration.test_timeout = 172
        stub_leased(one: 1, two: 2)

        expect(queue).to receive(:repush).with(:one).once.ordered
        expect(queue).to receive(:repush).with(:two).once.ordered
        expect(queue).not_to receive(:repush)

        start_watchdog_in_the_same_thread

        expect(broadcaster).to have_received(:warn).with('one (Timeout: 2 minute(s) 52 second(s)) ' \
                                                         'but will be pushed back to the queue.')
        expect(broadcaster).to have_received(:warn).with('two (Timeout: 2 minute(s) 52 second(s)) ' \
                                                         'but will be pushed back to the queue.')
      end
    end

    describe 'timeout calculation' do
      context 'when none of the entries are timed out' do
        it 'does not pull back anything' do
          Timecop.freeze(Time.now - 59) do
            2.times { queue.lease }
          end

          expect(queue).not_to receive(:repush)

          start_watchdog_in_the_same_thread
        end
      end

      context 'when one of the entries is timed out' do
        it 'pulls back one entry' do
          Timecop.freeze(Time.now - 61) { queue.lease }
          Timecop.freeze(Time.now - 20) { queue.lease }
          expect(queue).to receive(:repush).with(:two).once
          expect(queue).not_to receive(:repush).with(:one)

          start_watchdog_in_the_same_thread
        end

        it 'reports entries to metrics' do
          Timecop.freeze(Time.now - 61) { queue.lease }
          expect(DistribCore::Metrics).to receive(:watchdog_repushed).with(:two, 60).once

          start_watchdog_in_the_same_thread
        end
      end

      context 'when both of the entries are timed out' do
        it 'pulls back all entries' do
          Timecop.freeze(Time.now - 61) { queue.lease }
          Timecop.freeze(Time.now - 62) { queue.lease }
          expect(queue).to receive(:repush).with(:one).once
          expect(queue).to receive(:repush).with(:two).once

          start_watchdog_in_the_same_thread
        end
      end

      context 'when strategy is set to release timed out test' do
        it 'releases test' do
          configuration.timeout_strategy = :release
          Timecop.freeze(Time.now - 61) { queue.lease }
          expect(queue).to receive(:release).with(:two).once

          start_watchdog_in_the_same_thread
        end
      end
    end
  end

  describe 'shut down' do
    let(:queue) { instance_double(DistribCore::Leader::QueueWithLease, select_leased: {}, leased_size: 0) }

    context 'when the queue is empty' do
      it 'shuts down immediately' do
        allow(queue).to receive(:empty?).and_return(true)
        start_time = Time.now.to_f
        start_watchdog_in_the_same_thread
        expect(Time.now.to_f).to be_within(1.0).of(start_time)
      end
    end

    context 'when the queue eventually becomes empty' do
      it 'shuts down in several seconds' do
        allow(queue).to receive(:empty?).and_return(false, false, false, false, true)
        allow(queue).to receive(:visited?)
        allow(queue).to receive_messages(last_activity_at: Time.now, initialized_at: Time.now - 10,
                                         entries_list: [])
        expect(Kernel).to receive(:sleep).with(1).exactly(4).times

        start_watchdog_in_the_same_thread
      end
    end

    context 'when first test was not picked in configured time frame' do
      let(:first_test_picked_timeout) { 60 }

      before do
        configuration.first_test_picked_timeout = first_test_picked_timeout
        allow(broadcaster).to receive(:error)
        allow(broadcaster).to receive(:info)
        allow(queue).to receive_messages(
          empty?: false,
          visited?: false,
          initialized_at: Time.now - (2 * first_test_picked_timeout),
          entries_list: []
        )
      end

      it 'shuts down on timeout' do
        service = double
        allow(DRb).to receive(:current_server).and_return(service)
        expect(service).to receive(:stop_service)

        start_watchdog_in_the_same_thread
      end

      it 'logs the correct error message' do
        expected_message = <<~EXPECTED.strip
          Leader has reached the time limit of 1 minute(s) for the first test being picked from the queue.
          This probably means that all workers have failed to be initialized or took too long to start.
          Leader will now abort.
          Aborting...
        EXPECTED

        start_watchdog_in_the_same_thread

        expect(broadcaster).to have_received(:error).with(expected_message)
      end

      context 'when the queue has had activity' do
        before do
          allow(queue).to receive(:last_activity_at).and_return(Time.now - 1)
        end

        it 'does not timeout' do
          allow(queue).to receive(:empty?).and_return(false, true)
          allow(queue).to receive(:visited?).and_return(true)
          expect(broadcaster).not_to receive(:error)

          start_watchdog_in_the_same_thread
        end
      end
    end

    context 'when workers stopped processing tests for configured time frame' do
      let(:tests_processing_stopped_timeout) { 60 }

      before do
        configuration.tests_processing_stopped_timeout = tests_processing_stopped_timeout
        allow(broadcaster).to receive(:error)
        allow(broadcaster).to receive(:info)
        allow(queue).to receive_messages(
          visited?: true,
          empty?: false,
          initialized_at: Time.now - (2 * tests_processing_stopped_timeout),
          completed_size: 10,
          last_activity_at: Time.now - tests_processing_stopped_timeout - 1,
          entries_list: []
        )
      end

      it 'shuts down on timeout' do
        start_watchdog_in_the_same_thread

        expect(broadcaster).to have_received(:error).with(/Workers did not pick tests for too long!/)
      end

      it 'logs the correct error message' do
        expected_message = <<~EXPECTED.strip
          Workers did not pick tests for too long!
          After Workers processed 10 test(s), Leader will abort as it waited for over
          1 minute(s) which is the configured time to wait for
          Workers to pick up tests.
          Aborting...
        EXPECTED

        start_watchdog_in_the_same_thread

        expect(broadcaster).to have_received(:error).with(expected_message)
      end
    end

    context 'when there are some test still in the queue after leader has aborted' do
      let(:queue) { DistribCore::Leader::QueueWithLease.new(%i[one two]) }

      before do
        configuration.tests_processing_stopped_timeout = 60
        allow(broadcaster).to receive(:error)
        allow(broadcaster).to receive(:info)
        allow(broadcaster).to receive(:warn)
      end

      it 'logs the stuck tests to STDOUT' do
        Timecop.freeze(Time.now - 61) do
          2.times { queue.lease }
        end
        expected_message = <<~EXPECTED
          2 tests not executed, showing 2:
          one
          two
        EXPECTED
        start_watchdog_in_the_same_thread

        expect(broadcaster).to have_received(:info).with(expected_message)
      end
    end

    describe 'at shutdown' do
      it 'prints results and stops service' do
        allow(queue).to receive(:empty?).and_return(true)
        expect(DRb).to receive_message_chain(:current_server, :stop_service) # rubocop:disable RSpec/MessageChain

        start_watchdog_in_the_same_thread
      end
    end
  end
end

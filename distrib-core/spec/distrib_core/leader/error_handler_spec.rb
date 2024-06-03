# frozen_string_literal: true

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe DistribCore::Leader::ErrorHandler do
  let(:instance) { described_class.new(exception_extractor) }
  let(:exception_extractor) { double }
  let(:failure) { nil }

  before do
    allow(exception_extractor).to receive(:unpack_causes).and_return([[failure]])
  end

  describe '#retry_test?' do
    subject(:should_retry) { instance.retry_test?(test, results, exception) }

    let(:test) { 'foo_spec.rb' }
    let(:results) { [double] }
    let(:failure) { double(original_class: 'FooError', cause: nil, message: 'foo', backtrace: []) }
    let(:exception) { nil }

    shared_examples 'checks' do
      it 'returns false' do
        expect(should_retry).to be(false)
      end

      context 'when retries configured without list of exceptions' do
        before do
          instance.retry_attempts = 1
        end

        it 'returns true' do
          expect(should_retry).to be(true)
        end
      end

      context 'when list of exceptions configured without retries' do
        before do
          instance.retryable_exceptions = ['FooError']
        end

        it 'returns false' do
          expect(should_retry).to be(false)
        end
      end

      context 'when retries configured but got another error' do
        before do
          instance.retry_attempts = 1
          instance.retryable_exceptions = ['BarError']
        end

        it 'returns false' do
          expect(should_retry).to be(false)
        end
      end

      context 'when should retry' do
        before do
          instance.retry_attempts = 1
          instance.retryable_exceptions = ['FooError']
        end

        it 'returns true' do
          expect(should_retry).to be(true)
        end

        it 'returns false if retries depleted' do
          instance.retry_test?(test, results, exception)
          expect(should_retry).to be(false)
        end
      end
    end

    context 'when failed example' do
      before { allow(exception_extractor).to receive(:failures_of).and_return([failure]) }

      include_examples 'checks'
    end

    context 'when failed outside of example' do
      let(:exception) { failure }

      before { allow(exception_extractor).to receive(:failures_of).and_return([]) }

      include_examples 'checks'
    end
  end

  describe '#ignore_worker_failure?' do
    subject(:should_ignore) { instance.ignore_worker_failure?(exception) }

    let(:exception) { double(original_class: 'FooError', cause: nil, message: 'foo', backtrace: []) }
    let(:failure) { exception }
    let(:broadcaster) { instance_double(DistribCore::LoggerBroadcaster) }

    before do
      configuration = instance_double(DistribCore::Configuration)
      allow(configuration).to receive(:broadcaster).and_return(broadcaster)
      allow(DistribCore::Configuration).to receive(:current).and_return(configuration)
    end

    context 'with threshold set, but without fatal failures set' do
      before do
        instance.failed_workers_threshold = 1
      end

      it 'returns true' do
        expect(should_ignore).to be(true)
      end
    end

    context 'when non-fatal error occurs' do
      before do
        instance.failed_workers_threshold = 1
        instance.fatal_worker_failures = ['BarError']
      end

      it 'returns true' do
        expect(should_ignore).to be(true)
      end
    end

    context 'when there is a missing exception' do
      let(:exception) { nil }

      it 'returns false' do
        expect(broadcaster).to receive(:debug).with('Exception missing')
        expect(should_ignore).to be(false)
      end
    end

    context 'when the threshold is exceeded' do
      before do
        instance.failed_workers_threshold = 1
        instance.ignore_worker_failure?(exception)
      end

      it 'returns false' do
        expect(broadcaster).to receive(:debug).with('2 failure(s) reported, which exceeds the threshold of 1')
        expect(should_ignore).to be(false)
      end
    end

    context 'when fatal failure occurs' do
      before do
        instance.failed_workers_threshold = 1
        instance.fatal_worker_failures = ['FooError']
      end

      it 'returns false' do
        expect(broadcaster).to receive(:debug).with('Fatal failure found: FooError')
        expect(should_ignore).to be(false)
      end
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles

# frozen_string_literal: true

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe DistribCore::Leader::RetryOnDifferentErrorHandler do
  subject(:handler) do
    described_class.new(exception_extractor,
                        retry_limit:,
                        repeated_error_limit:)
  end

  before do
    stub_failure(failure)
  end

  def stub_failure(failure)
    allow(exception_extractor).to receive_messages(failures_of: [failure], unpack_causes: [[failure]])
  end

  describe '#retry_test?' do
    subject(:should_retry) { handler.retry_test?(test, results, exception) }

    let(:test) { 'foo_spec.rb' }
    let(:results) { [double] }
    let(:failure) { double(original_class: 'FooError', cause: nil, message: 'foo', backtrace: []) }
    let(:other_failure) { double(original_class: 'OtherFooError', cause: nil, message: 'foo', backtrace: []) }
    let(:exception) { nil }
    let(:exception_extractor) { double }
    let(:retry_limit) { 3 }
    let(:repeated_error_limit) { 2 }

    context 'when it is the first time failing' do
      it { is_expected.to be_truthy }
    end

    context "when repeated error limit isn't set" do
      let(:handler) do
        described_class.new(exception_extractor,
                            retry_limit:)
      end

      it { is_expected.to be_truthy }
    end

    context 'when it fails under retry limit and under repeated error limit with the same exception' do
      before do
        (repeated_error_limit - 1).times do
          stub_failure(failure)

          handler.retry_test?(test, results, exception)
        end
      end

      it { is_expected.to be_truthy }
    end

    context 'when it fails under retry limit and over repeated error limit with the same exception' do
      before do
        repeated_error_limit.times do
          stub_failure(failure)

          handler.retry_test?(test, results, exception)
        end
      end

      it { is_expected.to be_falsey }
    end

    context 'when it fails with a different exception under retry limit' do
      before do
        handler.retry_test?(test, results, exception)

        stub_failure(other_failure)
      end

      it { is_expected.to be_truthy }
    end

    context 'when it fails with a different message under retry limit' do
      let(:other_failure) { double(original_class: 'FooError', cause: nil, message: 'OTHER', backtrace: []) }

      before do
        handler.retry_test?(test, results, exception)

        stub_failure(other_failure)
      end

      it { is_expected.to be_truthy }
    end

    context 'when it fails over retry_limit with a different exception' do
      before do
        retry_limit.times do |i|
          stub_failure(double(original_class: "FooError#{i}", cause: nil, message: 'error', backtrace: []))

          handler.retry_test?(test, results, exception)
        end

        stub_failure(failure)
      end

      it { is_expected.to be_falsy }
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles

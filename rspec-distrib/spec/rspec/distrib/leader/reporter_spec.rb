# frozen_string_literal: true

# rubocop:disable RSpec/MessageChain
RSpec.describe RSpec::Distrib::Leader::Reporter do
  subject(:leader_reporter) { described_class.new }

  let(:reporter) { instance_double(RSpec::Core::Reporter) }

  before do
    allow(RSpec.configuration).to receive(:reporter).and_return(reporter)
    allow(RSpec.configuration).to receive(:add_formatter)
    allow(reporter).to receive(:start).with(RSpec::Distrib::Leader::FAKE_TOTAL_EXAMPLES_COUNT)
    allow(reporter).to receive(:example_group_started)
    allow(reporter).to receive(:example_group_finished)
    allow(reporter).to receive(:example_started)
    allow(reporter).to receive(:example_finished)
    allow(reporter).to receive(:example_passed)
    allow(reporter).to receive(:example_failed)
    allow(reporter).to receive(:example_pending)
  end

  describe '#report' do
    let(:execution_result) { instance_double(RSpec::Distrib::ExecutionResults, status: :passed) }
    let(:example_result) { instance_double(RSpec::Distrib::ExampleResult, execution_result:) }
    let(:example_group) { instance_double(RSpec::Distrib::ExampleGroup, children:, examples:) }
    let(:children) { [] }
    let(:examples) { [example_result] }
    let(:progress_formatter) { instance_double(RSpec::Core::Formatters::ProgressFormatter) }
    let(:html_formatter) { instance_double(RSpec::Core::Formatters::HtmlFormatter) }

    before do
      allow(RSpec.configuration).to receive(:formatters).and_return([progress_formatter, html_formatter])
      allow(progress_formatter)
        .to receive_messages(example_passed: true, example_failed: true, example_pending: true)
      allow(html_formatter).to receive_messages(example_failed: true, example_pending: true)
      allow(progress_formatter).to receive(:is_a?) { |klass| klass == RSpec::Core::Formatters::ProgressFormatter }
      allow(html_formatter).to receive(:is_a?) { |klass| klass == RSpec::Core::Formatters::HtmlFormatter }
      allow(reporter).to receive_message_chain(:examples, :<<)
    end

    it 'only starts the reporter once' do
      another_results = [instance_double(RSpec::Distrib::ExampleResult, execution_result:)]
      another_group = instance_double(RSpec::Distrib::ExampleGroup, children: [], examples: another_results)
      expect(reporter).to receive(:start).once
      leader_reporter.report(example_group)
      leader_reporter.report(another_group)
    end

    context 'when example group has nested groups' do
      let(:all_examples) do
        Array.new(3) do
          instance_double(RSpec::Distrib::ExampleResult, execution_result:)
        end
      end
      let(:examples) { all_examples[2..] }
      let(:children) do
        [instance_double(RSpec::Distrib::ExampleGroup, children: [], examples: all_examples[0..2])]
      end

      it 'reports all the examples' do
        all_examples.each do |example_result|
          expect(reporter).to receive(:example_started).with(example_result)
        end
        leader_reporter.report(example_group)
      end
    end

    context 'when example status is :passed' do
      it 'adds to examples' do
        result = instance_double(RSpec::Distrib::ExampleResult, execution_result:)
        example_group = instance_double(RSpec::Distrib::ExampleGroup, children: [], examples: [result])
        expect(reporter).to receive(:example_passed).with(result)
        leader_reporter.report(example_group)
      end
    end

    context 'when example status is :failed' do
      let(:execution_result) { instance_double(RSpec::Distrib::ExecutionResults, status: :failed) }

      it 'adds to examples and failed_examples' do
        expect(reporter).to receive(:example_started).with(example_result)
        expect(reporter).to receive(:example_failed).with(example_result)
        leader_reporter.report(example_group)
      end
    end

    context 'when example status is :pending' do
      let(:execution_result) { instance_double(RSpec::Distrib::ExecutionResults, status: :pending) }

      it 'adds to examples and pending_examples' do
        expect(reporter).to receive(:example_started).with(example_result)
        expect(reporter).to receive(:example_pending).with(example_result)
        leader_reporter.report(example_group)
      end
    end

    context 'when example status is not acceptable' do
      it 'adds to examples and pending_examples' do
        unacceptable_result = instance_double(RSpec::Distrib::ExecutionResults, status: :unacceptable)
        result = instance_double(RSpec::Distrib::ExampleResult, execution_result: unacceptable_result)
        example_group = instance_double(RSpec::Distrib::ExampleGroup, children: [], examples: [result])
        expect { leader_reporter.report(example_group) }
          .to raise_error(/Example status not valid: 'unacceptable'/)
      end
    end

    context 'when it will be retried' do
      context 'when the example is failed' do
        let(:execution_result) { instance_double(RSpec::Distrib::ExecutionResults, status: :failed) }

        it 'reports it only as a retry' do
          expect(reporter).not_to receive(:example_started)
          expect(reporter).not_to receive(:example_finished)

          expect(reporter).to receive(:publish).with(:example_will_be_retried, example: example_result)

          leader_reporter.report(example_group, will_be_retried: true)
        end
      end

      context 'when the example is passed' do
        let(:execution_result) { instance_double(RSpec::Distrib::ExecutionResults, status: :passed) }

        it 'does not report as retry' do
          expect(reporter).not_to receive(:publish)

          leader_reporter.report(example_group, will_be_retried: true)
        end
      end
    end
  end

  describe '#finish' do
    it 'finishes the report' do
      expect(reporter).to receive(:finish)
      leader_reporter.finish
    end
  end

  describe '#failures?' do
    it 'returns true if there are failures' do
      allow(reporter).to receive(:failed_examples).and_return(%i[failed.rb])
      expect(leader_reporter.failures?).to be(true)
    end
  end

  describe '#notify_non_example_exception' do
    it 'notifies rspec reporter' do
      expect(reporter).to receive(:notify_non_example_exception).with(:exception, :context)
      leader_reporter.notify_non_example_exception(:exception, :context)
    end
  end
end
# rubocop:enable RSpec/MessageChain

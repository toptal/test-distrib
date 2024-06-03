# frozen_string_literal: true

RSpec.describe RSpec::Distrib::ExecutionResults::Exception do
  subject(:exception) { described_class.new(original_exception) }

  before do
    stub_const('DummyError', Class.new(StandardError))
  end

  it do
    original_exception_cause = StandardError.new('foo')
    original_exception_cause.set_backtrace %w[4 5 6]
    original_exception = DummyError.new('bar')
    original_exception.set_backtrace %w[1 2 3]
    allow(original_exception).to receive(:cause).and_return(original_exception_cause)

    exception = described_class.new(original_exception)

    expect(exception.message).to eq original_exception.message
    expect(exception.backtrace).to eq original_exception.backtrace
    expect(exception.original_class).to eq 'DummyError'
    expect(exception.cause.message).to eq original_exception_cause.message
    expect(exception.cause.backtrace).to eq original_exception_cause.backtrace
    expect(exception.cause.original_class).to eq 'StandardError'
    expect(exception.cause.cause).to be_nil
  end

  it do
    exception1 = StandardError.new('Foo')
    exception1.set_backtrace %w[1 2 3]
    exception2 = DummyError.new('Bar')
    exception2.set_backtrace %w[4 5 6]

    multiple_exceptions_error = RSpec::Core::MultipleExceptionError.new(exception1, exception2)
    exception = described_class.new(multiple_exceptions_error)

    expect(exception.message).to eq "Got 0 failures and 2 other errors:\nStandardError: Foo\n\nAND\n\nDummyError: Bar"
    expect(exception.backtrace).to eq exception1.backtrace + ['AND'] + exception2.backtrace
  end
end

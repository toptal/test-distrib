# frozen_string_literal: true

RSpec.describe DistribCore::Leader::DRbCallable do # rubocop:disable RSpec/FilePath, RSpec/SpecFilePathFormat
  subject(:object) do
    Class.new do
      extend DistribCore::Leader::DRbCallable

      def initialize(handler, logger)
        @handler = handler
        @logger = logger
      end

      attr_reader :handler, :logger

      drb_callable def wrapped_function(*args)
        raise args.first if args.first.is_a?(Exception)

        puts args
      end

      def handle_non_example_exception
        handler.handle_non_example_exception
      end
    end.new(handler, logger)
  end

  let(:handler) { double }
  let(:logger) { instance_double(Logger) }

  it 'passes all arguments to original function and returns nil' do
    expect($stdout).to receive(:puts).with(['asd', 1])
    expect(object.wrapped_function('asd', 1)).to be_nil
  end

  it 'catches and records any raised error' do
    error = StandardError.new('asd')
    expect(logger).to receive(:error).with('Failed to call wrapped_function')
    expect(logger).to receive(:error).with(error)
    expect(handler).to receive(:handle_non_example_exception)
    expect($stdout).not_to receive(:puts)
    expect { object.wrapped_function(error) }.not_to raise_error
  end

  it 'prevents call if args has a DRbUnknown' do
    allow(DistribCore::DRbHelper).to receive(:drb_unknown?).with(1, 'asd').and_return(true)
    expect(handler).to receive(:handle_non_example_exception)
    expect($stdout).not_to receive(:puts)
    object.wrapped_function(1, 'asd')
  end
end

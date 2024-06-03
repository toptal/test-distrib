# frozen_string_literal: true

RSpec.describe DistribCore::LoggerBroadcaster do
  subject(:broadcaster) do
    described_class.new(loggers)
  end

  let(:loggers) { [info_logger, debug_logger] }
  let(:info_logger) { Logger.new(nil, level: Logger::INFO) }
  let(:debug_logger) { Logger.new(nil, level: Logger::DEBUG) }

  describe '#add' do
    # Role of broadcaster is to call each logger.
    # They decide on themselves if message should be printed or not.
    it 'all loggers are called' do
      expect(loggers).to all(receive(:add).with(Logger::DEBUG, nil, 'hello'))

      # debug, info, etc - all call `add`
      broadcaster.debug 'hello'
    end
  end

  describe '#<<' do
    it 'all loggers are called' do
      expect(loggers).to all(receive(:<<).with('hello'))

      broadcaster << 'hello'
    end
  end

  %i[close reopen].each do |method|
    describe "##{method}" do
      it 'all loggers are called' do
        expect(loggers).to all(receive(method))

        broadcaster.public_send(method)
      end
    end
  end
end

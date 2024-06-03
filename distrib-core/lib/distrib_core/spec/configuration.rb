# Shared examples to test configuration.
RSpec.shared_examples 'DistribCore configuration' do
  around do |example|
    config = DistribCore::Configuration.instance_variable_get(:@current)
    DistribCore::Configuration.instance_variable_set(:@current, nil)
    example.run
    DistribCore::Configuration.instance_variable_set(:@current, config)
  end

  describe '.current' do
    it 'raise error when configuration is missing' do
      expect { DistribCore::Configuration.current }.to raise_error(RuntimeError)
    end
  end

  describe '.current =' do
    it 'raise error if sets it more than once' do
      some_config = Object.new
      DistribCore::Configuration.current = some_config
      expect(DistribCore::Configuration.current).to eq(some_config)
      another_config = Object.new
      expect { DistribCore::Configuration.current = another_config }.to raise_error(RuntimeError)
      expect { DistribCore::Configuration.current = some_config }.not_to raise_error
    end
  end

  it 'initialization sets global value' do
    configuration
    expect(DistribCore.configuration).to eq configuration
  end

  it 'has default options' do
    expect(configuration.test_timeout).to be_positive
    expect(configuration.first_test_picked_timeout).to be_positive
    expect(configuration.tests_processing_stopped_timeout).to be_positive
    expect(configuration.drb[:safe_level]).to be 1
  end

  it 'has default logger' do
    expect(configuration.logger).not_to be_nil
    expect(configuration.logger.level).to eq(Logger::INFO)
  end

  it 'has debug logger' do
    expect(configuration.debug_logger).not_to be_nil
    expect(configuration.debug_logger.level).to eq(Logger::DEBUG)
  end

  it 'has broadcaster' do
    expect(configuration.broadcaster).to be_instance_of(DistribCore::LoggerBroadcaster)
    expect(configuration).not_to respond_to(:broadcaster=)
  end

  describe '#timeout_for' do
    it 'returns test_timeout for any file' do
      expect(configuration.timeout_for('any_test')).to eq configuration.test_timeout
    end

    it 'calls test_timeout if it is Proc' do
      handler = ->(test) { "Value for #{test}" }
      configuration.test_timeout = handler
      expect(configuration.timeout_for('foo')).to eq('Value for foo')
    end
  end

  describe '#timeout_strategy=' do
    specify do
      expect(configuration.timeout_strategy).to eq(:repush)

      configuration.timeout_strategy = :release
      expect(configuration.timeout_strategy).to eq(:release)

      expect do
        configuration.timeout_strategy = :invalid
      end.to raise_error(RuntimeError, /Invalid Timeout Strategy/)
    end
  end
end

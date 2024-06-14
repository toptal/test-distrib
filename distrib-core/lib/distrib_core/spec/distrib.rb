RSpec.shared_examples 'DistribCore root module' do
  around do |example|
    config = DistribCore::Configuration.instance_variable_get(:@current)
    DistribCore::Configuration.instance_variable_set(:@current, nil)
    example.run
  ensure
    DistribCore::Configuration.instance_variable_set(:@current, config)
  end

  def configure(...)
    root.configure(...)
  end

  def configuration
    DistribCore.configuration
  end

  it 'can change tests provider' do
    configure do |config|
      config.tests_provider = :foo
    end

    expect(configuration.tests_provider).to eq(:foo)
  end

  describe '#test_timeout' do
    it 'can change the test timeout using Integer' do
      configure do |config|
        config.test_timeout = 30
      end

      expect(configuration.test_timeout).to eq(30)
    end

    it 'can change the test timeout using Proc' do
      callable = ->(_file) { 30 }

      configure do |config|
        config.test_timeout = callable
      end

      expect(configuration.test_timeout).to eq(callable)
    end
  end

  it 'can change first_test_picked_timeout' do
    configure do |config|
      config.first_test_picked_timeout = 60
    end

    expect(configuration.first_test_picked_timeout).to eq(60)
  end

  it 'can change tests_processing_stopped_timeout' do
    configure do |config|
      config.tests_processing_stopped_timeout = 60
    end

    expect(configuration.tests_processing_stopped_timeout).to eq(60)
  end
end

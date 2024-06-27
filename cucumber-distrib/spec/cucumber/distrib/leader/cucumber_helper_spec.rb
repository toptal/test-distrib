# frozen_string_literal: true

RSpec.describe Cucumber::Distrib::Leader::CucumberHelper do
  describe '.failures_of' do
    it do
      errors = [
        Cucumber::Distrib::Events::Exception.new(StandardError.new('QWE')),
        Cucumber::Distrib::Events::Exception.new(ArgumentError.new('ASD')),
        Cucumber::Distrib::Events::Exception.new(RuntimeError.new('ZXC'))
      ]

      events = errors.map do |error|
        instance_double(
          Cucumber::Distrib::Events::TestCaseFinished,
          result: instance_double(::Cucumber::Core::Test::Result::Failed, exception: error)
        )
      end

      expect(described_class.failures_of(events)).to eq errors
    end
  end

  describe '.unpack_causes' do
    it do
      errors = [StandardError.new('ASD')]
      errors_tree = [errors[0]]

      begin
        begin
          raise 'QWE'
        rescue StandardError => e
          errors << e
          raise ArgumentError, 'ZXC'
        end
      rescue StandardError => e
        errors << e
        errors_tree << e
      end

      expect(described_class.unpack_causes(errors_tree)).to contain_exactly([errors[0]], [errors[2], errors[1]])
    end
  end
end

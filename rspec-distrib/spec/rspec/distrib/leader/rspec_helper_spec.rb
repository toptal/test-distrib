# frozen_string_literal: true

RSpec.describe RSpec::Distrib::Leader::RSpecHelper do # rubocop:disable RSpec/SpecFilePathFormat
  describe '.failures_of' do
    it do
      errors = [
        RSpec::Distrib::ExecutionResults::Exception.new(StandardError.new('QWE')),
        RSpec::Distrib::ExecutionResults::Exception.new(ArgumentError.new('ASD')),
        RSpec::Distrib::ExecutionResults::Exception.new(RuntimeError.new('ZXC'))
      ]

      example_groups = []
      errors.each do |error|
        example_groups = [
          instance_double(
            RSpec::Distrib::ExampleGroup,
            examples: [instance_double(RSpec::Distrib::ExampleResult, exception: error)],
            children: example_groups
          )
        ]
      end

      expect(described_class.failures_of(example_groups)).to eq errors.reverse
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

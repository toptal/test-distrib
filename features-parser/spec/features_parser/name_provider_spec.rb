# frozen_string_literal: true

RSpec.describe FeaturesParser::NameProvider do
  subject(:provider) { described_class.new(cucumber_object) }

  let(:cucumber_feature) do
    # No original class loaded to verify
    double(name: 'Some Feature', location: double(file: 'some.feature'))
  end

  context 'when the object is a scenario' do
    let(:cucumber_object) do
      # No original class loaded to verify
      double(
        outline?: false,
        name: 'Some scenario',
        location: double(line: 5),
        feature: cucumber_feature
      )
    end

    it 'returns normalized name' do
      expect(provider.normalized_name).to eq 'some-feature/some-scenario'
    end
  end

  context 'when the object is an example' do
    let(:cucumber_object) do
      # No original class loaded to verify
      double(
        outline?: true,
        name: 'Some, example, that may contain commas, Scenarios Section Title (#5)',
        location: double(line: 5),
        cell_values: %w[admin 7% $1,200],
        feature: cucumber_feature
      )
    end

    it 'returns normalized name' do
      expected_name = 'some-feature/some-example-that-may-contain-commas/admin|7|1-200'
      expect(provider.normalized_name).to eq expected_name
    end
  end
end

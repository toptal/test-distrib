# frozen_string_literal: true

RSpec.describe FeaturesParser::Scenario do
  subject(:scenario) { described_class.new(feature, ast) }

  let(:feature) do
    instance_double(
      FeaturesParser::Feature,
      normalized_name: 'normalized-feature-name',
      executable_path: 'some.feature'
    )
  end

  let(:ast) do
    Cucumber::Messages::Scenario.new(
      name: 'My scenario',
      location: Cucumber::Messages::Location.new(line: 3),
      keyword: 'Scenario'
    )
  end

  it "returns original scenario's basic info" do
    expect(scenario.name).to eq 'My scenario'
    expect(scenario.line).to eq 3
    expect(scenario.executable_path).to eq 'some.feature:3'
  end

  describe '#normalized_name' do
    def mock_name_normalizer
      allow(FeaturesParser::NameNormalizer).to receive(:normalize).with('My scenario').and_return('pants')
    end

    before { mock_name_normalizer }

    it 'includes feature name and scenario name' do
      expect(scenario.normalized_name).to eq 'normalized-feature-name/pants'
    end

    it 'memoizes normalized name' do
      expect(feature).to receive(:normalized_name).once
      expect(FeaturesParser::NameNormalizer).to receive(:normalize).once

      2.times { scenario.normalized_name }
    end
  end
end

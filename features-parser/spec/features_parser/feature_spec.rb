# frozen_string_literal: true

RSpec.describe FeaturesParser::Feature do
  subject(:feature) { described_class.new(ast, path) }

  let(:ast) do
    Cucumber::Messages::Feature.new(name: 'My feature')
  end

  let(:path) { 'some.feature' }

  it "has original feature's name and executable_path" do
    expect(feature.name).to eq 'My feature'
    expect(feature.executable_path).to eq path
  end

  context 'when incorrect type' do
    let(:ast) { Cucumber::Messages::Scenario.new }

    it 'complains about incorrect type' do
      expect { feature }.to raise_error('Incorrect node supplied: Cucumber::Messages::Scenario')
    end
  end

  describe '#normalized_name' do
    before do
      allow(FeaturesParser::NameNormalizer).to receive(:normalize).with('My feature').and_return('pants')
    end

    it 'delegates normalization to NameNormalizer' do
      expect(feature.normalized_name).to eq('pants')
    end

    it 'memoizes value from NameNormalizer' do
      expect(FeaturesParser::NameNormalizer).to receive(:normalize).once

      2.times { feature.normalized_name }
    end
  end
end

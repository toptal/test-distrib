# frozen_string_literal: true

RSpec.describe FeaturesParser::ScenarioParser do
  subject(:parsed_names) { described_class.new(catalog:).parse([file]) }

  let(:catalog) { FeaturesParser::Catalog.new }
  let(:file) { 'spec/support/some.feature' }

  let(:scenario) do
    'user-does-random-things/sending-as-a-guest-user'
  end

  let(:outline_examples) do
    %w[
      user-does-random-things/staff-sends-feedback/user|john-doe-com
      user-does-random-things/staff-sends-feedback/moderator|agent-smith-com
      user-does-random-things/staff-sends-feedback/admin|neo-matrix-com
    ]
  end

  let(:scenarios_examples) do
    %w[
      user-does-random-things/client-gets-discount/organic|5|15
      user-does-random-things/client-gets-discount/ad-campaign|10|5
      user-does-random-things/client-gets-discount/email|5|5
      user-does-random-things/client-gets-discount/social-media|10|10
    ]
  end

  it 'parses and returns normalized names' do
    expect(parsed_names).to eq([scenario] + outline_examples + scenarios_examples)
  end

  context 'when Catalog' do
    it 'registers parsed scenarios and outline examples in catalog' do
      lines = %w[10 26 27 28 37 38 42 43]
      expected_paths = lines.map { |line| [file, line].join(':') }
      all_names = [scenario] + outline_examples + scenarios_examples

      parsed_names

      expect(catalog.names).to eq all_names
      expect(catalog.executable_paths).to eq expected_paths
    end
  end

  describe 'parsing errors' do
    let(:file) { 'spec/support/parse-error.feature' }

    it 'provides filename with parse error' do
      expect { parsed_names }.to raise_error do |error|
        expect(error).to be_a(FeaturesParser::ScenarioParser::ParserError)
        expect(error.message).to match(/Filename: #{file}.+? got 'Background:'/m)
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe FeaturesParser::Example do
  subject(:example) { described_class.new(outline, ast) }

  let(:ast) do
    Cucumber::Messages::TableRow.new(
      location: Cucumber::Messages::Location.new(line: 26, column: 7),
      cells: [
        Cucumber::Messages::TableCell.new(
          location: Cucumber::Messages::Location.new(line: 26, column: 9),
          value: 'user'
        ),
        Cucumber::Messages::TableCell.new(
          location: Cucumber::Messages::Location.new(line: 26, column: 21),
          value: 'john@doe.com'
        )
      ]
    )
  end

  let(:outline) do
    instance_double(
      FeaturesParser::Outline,
      normalized_name: 'outline-name',
      executable_path: 'some.feature:22'
    )
  end

  it 'throws exception on incorrect type' do
    expect { described_class.new(outline, type: :unknown) }.to raise_error RuntimeError, /Incorrect node supplied/
  end

  it 'uses cell values in normalized name' do
    allow(FeaturesParser::NameNormalizer).to receive(:normalize) { |input| "#{input}-pants" }
    expect(example.normalized_name).to eq 'outline-name/user-pants|john@doe.com-pants'
  end

  it 'parses line number and has executable path' do
    expect(example.line).to eq 26
    expect(example.executable_path).to eq 'some.feature:26'
  end
end

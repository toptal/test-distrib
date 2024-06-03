# frozen_string_literal: true

RSpec.describe FeaturesParser::NameNormalizer do
  subject(:normalizer) { described_class }

  it 'uses dash as default separator' do
    expect(normalizer.normalize('some string')).to eq 'some-string'
  end

  it 'does not modify input string' do
    input = 'some input'
    normalizer.normalize(input)

    expect(input).to eq 'some input'
  end

  it 'supports custom separator' do
    expect(normalizer.normalize('some string', '/')).to eq 'some/string'
  end

  it 'converts non-letters and non-digits to separator' do
    expect(normalizer.normalize('underscored_text $#% dashed-text 123')).to eq 'underscored_text-dashed-text-123'
  end

  it 'squashes several separators into one' do
    expect(normalizer.normalize('several  separators')).to eq 'several-separators'
  end

  it 'removes separators in the beginning and in the end' do
    expect(normalizer.normalize('-  some text  -')).to eq 'some-text'
  end

  it 'downcases string' do
    expect(normalizer.normalize('PaNcAkEs')).to eq 'pancakes'
  end

  it 'passes combined test' do
    expect(normalizer.normalize(' !#$ PaNCakes % WILL  conqu3r... tHe world! -- '))
      .to eq 'pancakes-will-conqu3r-the-world'
  end
end

RSpec.describe 'Baz' do
  it { expect(3).to eq 3 }

  context do
    after do
      raise StandardError
    end

    it { expect(1).to eq 1 }
  end
end

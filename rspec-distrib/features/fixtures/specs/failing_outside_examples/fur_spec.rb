RSpec.describe 'Fur' do
  let!(:fail) { raise StandardError }

  it { expect(3).to eq 3 }
end

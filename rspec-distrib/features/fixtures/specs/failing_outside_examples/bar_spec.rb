RSpec.describe 'Bar' do
  before do
    raise StandardError
  end

  it { expect(1).to eq 1 }
end

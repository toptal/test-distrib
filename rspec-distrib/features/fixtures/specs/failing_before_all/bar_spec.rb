RSpec.describe 'Bar' do
  before(:all) do
    raise StandardError
  end

  it { expect(3).to eq 3 }
end

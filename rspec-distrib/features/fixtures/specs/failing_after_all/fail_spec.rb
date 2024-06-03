RSpec.describe 'Fail spec' do
  after(:all) do
    raise StandardError
  end

  it { expect(3).to eq 3 }
end

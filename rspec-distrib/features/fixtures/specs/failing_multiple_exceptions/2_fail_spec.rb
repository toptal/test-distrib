RSpec.describe '2 Fail spec' do
  after do
    fail StandardError, '2'
  end

  it { fail StandardError, '1' }
end

class RetryThisError < StandardError
end

RSpec.describe 'Foo' do
  it do
    case (Object.const_get(:FLAKY_RAISED) if Object.constants.include?(:FLAKY_RAISED))
    when nil
      puts 'Failing on first time'
      Object.const_set(:FLAKY_RAISED, 1)
      raise RetryThisError
    when 1
      puts 'Wrapping and failing on second time'
      Object.const_set(:FLAKY_RAISED, 2)
      begin
        raise RetryThisError
      rescue
        raise RuntimeError
      end
    when 2
      puts 'Pass on third time'
      expect(1).to eq 1
    end
  end
end

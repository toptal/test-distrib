class RetryThisError < StandardError
end

When('I fail several times') do
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
    rescue StandardError
      raise RuntimeError
    end
  when 2
    puts 'Pass on third time'
  end
end

Then('But pass in the end') do
  expect(1).to eq 1
end

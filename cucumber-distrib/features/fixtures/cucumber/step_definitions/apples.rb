apples = 0

When('I have {int} apples') do |number|
  apples = number
end

When('I buy {int} apples') do |number|
  sleep(1) # allow other workers to pick features
  apples += number
end

Then('I have {int} apples now') do |number|
  expect(apples).to eq(number)
end

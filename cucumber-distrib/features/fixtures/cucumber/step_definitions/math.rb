num = 0

When('I sum {int} and {int}') do |n1, n2|
  num = n1 + n2
end

Then('I get {int}') do |number|
  expect(num).to eq(number)
end

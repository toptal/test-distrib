# FeaturesParser

This is an abstraction over [Gherkin](https://github.com/cucumber/gherkin/tree/main/ruby) gem.

## Installation

Add the gem to the application's Gemfile:

```ruby
git 'git@github.com:toptal/test-distrib.git', branch: 'main' do
  gem 'features-parser'
end
```

## Usage

```shell
bin/console
```

```ruby
feature_file = 'spec/support/some.feature'
catalog = FeaturesParser::Catalog.new
catalog.parse([feature_file])

catalog.names.take(3)
# =>
# ["user-does-random-things/sending-as-a-guest-user",
# "user-does-random-things/staff-sends-feedback/user|john-doe-com",
# "user-does-random-things/staff-sends-feedback/moderator|agent-smith-com"]

executable_paths = catalog.executable_paths_for(['user-does-random-things/sending-as-a-guest-user'])
# => ["spec/support/some.feature:10"]

names = catalog.names_for(executable_paths)
# => ["user-does-random-things/sending-as-a-guest-user"]
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.
Run `bundle exec rubocop` to check code style.

## Contributing

Bug reports and pull requests are welcome [on GitHub](https://github.com/toptal/test-distrib/issues).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

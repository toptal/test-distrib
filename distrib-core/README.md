# distrib-core

This is a common core module for *-distrib runners.
At this point for [rspec-distrib](../rspec-distrib).

## Installation

Add the gem to the application's Gemfile:

```ruby
git 'git@github.com:toptal/test-distrib.git', branch: 'main' do
  gem 'distrib-core', require: false, group: [:test]
end
```

## Getting started

```shell
bundle install
bundle exec rspec
bundle exec rubocop
```

## Contributing

Bug reports and pull requests are welcome [on GitHub](https://github.com/toptal/test-distrib/issues).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = 'cucumber-distrib'
  s.version = '0.0.1'
  s.authors = ['Toptal, LLC']
  s.email = 'open-source@toptal.com'
  s.license = 'MIT'

  s.files = Dir['lib/**/*.rb'] + Dir['exe/*']
  s.bindir = 'exe'
  s.executables = ['cucumber-distrib']

  s.homepage = 'https://github.com/toptal/test-distrib'
  s.summary = 'Cucumber extension for distributed running of features from a queue.'
  s.description = ''
  s.required_ruby_version = '>= 3.2.4'

  s.add_dependency 'cucumber', '~> 7.1.0'
  s.add_dependency 'distrib-core', '~> 0.0.1'

  s.add_development_dependency 'pry'
  s.add_development_dependency 'pry-byebug'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec', '~> 3.8'
  s.add_development_dependency 'rubocop', '~> 1.65.0'
  s.add_development_dependency 'rubocop-rspec', '~> 3.0.1'
  s.add_development_dependency 'simplecov', '0.22.0'
  s.add_development_dependency 'yard'

  s.metadata['rubygems_mfa_required'] = 'true'
end

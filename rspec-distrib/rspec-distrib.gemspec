# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = 'rspec-distrib'
  s.version = '0.0.1'
  s.authors = ['Toptal, LLC']
  s.email = ['open-source@toptal.com']
  s.license = 'MIT'

  s.summary = 'RSpec extension for distributed running of specs from a queue.'
  s.description = ''
  s.homepage = 'https://github.com/toptal/test-distrib'
  s.required_ruby_version = '>= 3.2.4'

  s.files = Dir['lib/**/*.rb'] + Dir['exe/*']
  s.bindir = 'exe'
  s.executables = ['rspec-distrib']

  s.add_dependency 'distrib-core'
  s.add_dependency 'rspec-core', '~> 3.12'

  s.metadata['rubygems_mfa_required'] = 'true'
end

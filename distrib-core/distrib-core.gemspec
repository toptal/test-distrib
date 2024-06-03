# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = 'distrib-core'
  s.version = '0.0.1'
  s.authors = ['Toptal, LLC']
  s.email = ['open-source@toptal.com']
  s.license = 'MIT'

  s.summary = 'Core classes for rspec-distrib and cucumber-distrib'
  s.description = ''
  s.homepage = 'https://github.com/toptal/distrib-core'
  s.required_ruby_version = '>= 3.2.4'

  s.files = Dir['lib/**/*.rb']

  s.metadata['rubygems_mfa_required'] = 'true'
end

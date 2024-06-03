# frozen_string_literal: true

require_relative 'lib/features_parser/version'

Gem::Specification.new do |spec|
  spec.name = 'features-parser'
  spec.version = FeaturesParser::VERSION
  spec.authors = ['Toptal, LLC']
  spec.email = ['open-source@toptal.com']
  spec.license = 'MIT'

  spec.summary = 'Utility to parse features.'
  spec.description = 'Utility to parse features.'
  spec.homepage = 'https://github.com/toptal/test-distrib'
  spec.required_ruby_version = '>= 3.2.4'

  spec.files = Dir['lib/**/*.rb']
  spec.require_paths = ['lib']

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage

  spec.add_dependency 'activesupport'
  spec.add_dependency 'cucumber-gherkin'

  spec.metadata['rubygems_mfa_required'] = 'true'
end

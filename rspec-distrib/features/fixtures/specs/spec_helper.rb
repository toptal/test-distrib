# frozen_string_literal: true

abort('Abort worker in root') if ENV['RSPEC_DISTRIB_ABORT_WORKER'] == 'true'

require 'rspec'
require 'stringio'

RSpec.configure do |config|
  if ENV['RSPEC_DISTRIB_MULTIPLE_WORKERS'] == 'true'
    config.before(:all) do
      sleep 1 # let other workers pick the rest of specs
    end
  end

  if ENV['RSPEC_DISTRIB_FAIL_BEFORE_SUITE'] == 'true'
    config.before(:suite) do
      raise StandardError, 'Fail before suite'
    end
  end

  if ENV['RSPEC_DISTRIB_FAIL_AFTER_SUITE'] == 'true'
    config.after(:suite) do
      raise StandardError, 'Fail after suite'
    end
  end

  config.deprecation_stream = StringIO.new
end

if ENV['RSPEC_DISTRIB_FAIL_CONFIGURATION'] == 'true'
  raise StandardError, 'Fail configuration'
end

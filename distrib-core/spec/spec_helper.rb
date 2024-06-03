# frozen_string_literal: true

require 'bundler/setup'

if ENV['DISABLE_SIMPLECOV'] != '1'
  require 'simplecov'

  SimpleCov.start do
    add_filter '_spec.rb'
    command_name "distrib-core-#{Process.pid}"
  end

  SimpleCov.at_exit { SimpleCov.instance_variable_set('@result', nil) }
end

require 'English'
require 'distrib-core'
require 'timecop'

RSpec.configure do |config|
  if ENV['DISABLE_SIMPLECOV'] != '1'
    config.after(:suite) do
      SimpleCov.result.format!
    end
  end

  config.order = :random
  Kernel.srand config.seed
end

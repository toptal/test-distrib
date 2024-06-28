# frozen_string_literal: true

require_relative '../spec/spec_helper'

SimpleCov.add_filter 'features/support/' if ENV['DISABLE_SIMPLECOV'] != '1'

Dir[Pathname(__dir__).join('support', '**', '*.rb')].each { |f| require f }

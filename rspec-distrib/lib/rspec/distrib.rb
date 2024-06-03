require 'distrib_core'
require 'rspec/distrib/configuration'

# @see https://github.com/rspec/rspec
module RSpec
  # Core module to store configuration and some other global vars.
  module Distrib
    extend ::DistribCore::Distrib

    class << self
      # @return [RSpec::Distrib::Configuration]
      def configuration
        @configuration ||= ::RSpec::Distrib::Configuration.new
      end
    end
  end
end

# init default configuration
RSpec::Distrib.configuration

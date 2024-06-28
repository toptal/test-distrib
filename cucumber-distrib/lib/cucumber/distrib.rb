require 'distrib-core'
require 'cucumber/distrib/configuration'

# @see https://github.com/cucumber/cucumber-ruby
module Cucumber
  # Core module for Cucumber::Distrib.
  module Distrib
    extend ::DistribCore::Distrib

    class << self
      # @return [Cucumber::Distrib::Configuration]
      def configuration
        @configuration ||= ::Cucumber::Distrib::Configuration.new
      end
    end
  end
end

# Init configuration.
Cucumber::Distrib.configuration

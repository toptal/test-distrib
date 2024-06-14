module RSpec
  module Distrib
    module Worker
      # @api private
      # Custom configuration for RSpec which we use on workers to replace
      # regular reporter with {LeaderReporter}.
      class Configuration < RSpec::Core::Configuration
        # @return [DRbObject(RSpec::Distrib::Leader)]
        attr_accessor :leader

        # Overridden method which wraps original reporter with {LeaderReporter}.
        # @return RSpec::Core::Formatters::Loader
        def formatter_loader
          @formatter_loader ||= begin
            original_reporter = RSpec::Core::Reporter.new(self)
            wrapped_reporter = LeaderReporter.new(leader, original_reporter)
            RSpec::Core::Formatters::Loader.new(wrapped_reporter)
          end
        end

        # Always true because seed comes from leader.
        def seed_used?
          true
        end
      end
    end
  end
end

module Cucumber
  module Distrib
    class Leader
      # Default provider for tests. Looks for features at `features/**/*.feature`.
      class TestsProvider
        class << self
          # @return [Array<String>]
          def call
            Dir.glob('features/**/*.feature')
          end
        end
      end
    end
  end
end

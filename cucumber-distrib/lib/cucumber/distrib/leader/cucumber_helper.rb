module Cucumber
  module Distrib
    class Leader
      # Helper that handles some cases with Cucumber.
      class CucumberHelper
        class << self
          # Get failures of events.
          #
          # @param events [Array<Cucumber::Distrib::Events::Event>]
          # @return [Array<Exception>]
          def failures_of(events)
            events.map do |ev|
              ex = ev.result.exception
              # Collect only exceptions, not `pending` or `skipped` wrappers.
              ex.is_a?(::Cucumber::Core::Test::Result::Raisable) ? nil : ex
            rescue StandardError
              nil
            end.compact
          end

          # Extract all causes of exceptions to a list.
          #
          # @param exceptions [Array<Exception>]
          # @return [Array<Exception>]
          def unpack_causes(exceptions)
            exceptions.map do |exception|
              causes = []

              while exception
                causes << exception
                exception = exception.cause
              end

              causes
            end
          end
        end
      end
    end
  end
end

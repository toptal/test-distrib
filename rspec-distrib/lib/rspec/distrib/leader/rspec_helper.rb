module RSpec
  module Distrib
    class Leader
      # Helper that handles some cases with RSpec.
      module RSpecHelper
        class << self
          # Goes through all example_group tree and returns all failures as array.
          def failures_of(example_groups)
            fetch_all_failures_recursively(example_groups).flatten.compact.uniq
          end

          # Extract all causes for exceptions to a list.
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

          private

          def fetch_all_failures_recursively(example_groups)
            example_groups.map do |eg|
              eg.examples.map(&:exception) + fetch_all_failures_recursively(eg.children)
            end
          end
        end
      end
    end
  end
end

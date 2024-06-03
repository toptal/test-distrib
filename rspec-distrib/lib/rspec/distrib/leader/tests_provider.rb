module RSpec
  module Distrib
    class Leader
      # Default strategy to get a list of spec files to serve from
      # the queue. Gets spec files from spec directory.
      class TestsProvider
        class << self
          # @return [Array<String>] list of spec files to enqueue
          # @example ['spec/user_spec.rb', 'spec/users_controller_spec.rb']
          #
          # An application with a very long test suite might have better
          # results by ordering the specs by average execution time descending.
          def call
            Dir.glob('spec/**/*_spec.rb')
          end
        end
      end
    end
  end
end

require 'rspec/distrib'
require 'rspec/distrib/worker/rspec_runner'

module RSpec
  module Distrib
    # Wrapper around {RSpec::Distrib::RSpecRunner}
    module Worker
      # Start a worker instance with a given leader ip.
      #
      # @param leader_ip [String] the ip address of the DRb server of the leader
      def self.join(leader_ip)
        raise 'Leader IP should be specified' unless leader_ip && !leader_ip.empty?

        status = RSpec::Distrib::Worker::RSpecRunner.run_from_leader(leader_ip)
        exit(status) if status != 0
      end
    end
  end
end

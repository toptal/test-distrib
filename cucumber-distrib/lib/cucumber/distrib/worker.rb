require 'cucumber/distrib'
require 'cucumber/distrib/worker/cucumber_runner'

module Cucumber
  module Distrib
    # Wrapper around {Cucumber::Distrib::Worker::CucumberRunner}.
    module Worker
      # Start a worker instance with a given leader IP.
      # @param leader_ip [String] the IP address of the DRb server of Leader
      def self.join(leader_ip)
        raise 'Leader IP should be specified' unless leader_ip && !leader_ip.empty?

        status = Cucumber::Distrib::Worker::CucumberRunner.run_from_leader(leader_ip)
        exit(status) if status != 0
      end
    end
  end
end

require 'distrib_core/core_ext/drb_tcp_socket'
require 'distrib_core/logger_broadcaster'
require 'distrib_core/leader'
require 'distrib_core/configuration'
require 'distrib_core/distrib'
require 'distrib_core/drb_helper'
require 'distrib_core/metrics'
require 'distrib_core/received_signals'
require 'distrib_core/worker'

# A core module. Has a quick alias to configuration.
module DistribCore
  # Alias to {DistribCore::Configuration.current}
  def self.configuration
    Configuration.current
  end
end

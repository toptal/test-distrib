module DistribCore
  # Stores common methods for Workers (basic module for workers).
  module Worker
    private

    def connect_to_leader_with_timeout
      tries = 0
      max_tries = DistribCore::Configuration.current.leader_connection_attempts

      begin
        yield
      rescue DRb::DRbConnError
        tries += 1
        sleep 1
        retry if tries < max_tries
        raise
      end
    end

    def received_any_signal?
      ::DistribCore::ReceivedSignals.any?
    end

    def received_int?
      ::DistribCore::ReceivedSignals.received?('INT')
    end

    def received_force_int?
      ::DistribCore::ReceivedSignals.force_int?
    end

    def received_term?
      ::DistribCore::ReceivedSignals.received?('TERM')
    end

    def logger
      DistribCore.configuration.logger
    end
  end
end

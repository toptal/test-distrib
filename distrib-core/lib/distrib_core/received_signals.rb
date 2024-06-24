module DistribCore
  # A handler for signal interruptions (like INT and TERM).
  # Stores information about received signals.
  module ReceivedSignals
    class << self
      # Defines trap for singlas and collects them.
      # Exits after second 'INT'
      #
      # @param sig [String] signal to trap
      # @example
      #     ::DistribCore::ReceivedSignals.trap('INT')
      def trap(sig)
        Signal.trap(sig) do
          # Second SIGINT finishes the process immediately
          if sig == 'INT' && signals.member?('INT')
            @force_int = true
            puts 'Received second SIGINT. Exiting...'
            Kernel.exit(2) # 2 is exit code for SIGINT
          end

          puts "Received #{sig}"
          signals.add(sig)
        end
      end

      # @return [TrueClass, FalseClass] `true` when received any signal
      def any?
        signals.any?
      end

      # @param sig [String]
      # @return [TrueClass, FalseClass] `true` if signal `sig` was received
      def received?(sig)
        signals.member?(sig)
      end

      # @return [TrueClass, FalseClass] `true` if 'INT' was sent twice
      def force_int?
        @force_int
      end

      # @return [String] human-readable message about received signals
      def message
        "RECEIVED SIGNAL #{signals.to_a.join(', ')}." if any?
      end

      # @return [Integer] proper exit code based on received signal
      def exit_code
        return 0 if signals.empty?

        Signal.list[signals.first]
      end

      # @return [Set<String>] list of received signals
      def signals
        @signals ||= Set.new
      end
    end
  end
end

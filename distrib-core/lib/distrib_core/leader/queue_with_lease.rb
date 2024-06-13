require 'timeout'
require 'monitor'

module DistribCore
  module Leader
    # Generic queue-like, thread-safe container with lease.
    #
    # Additionally it keeps the time of the lease, allowing watchdog to return
    # (repush) timed out entries back to the queue.
    #
    # Lifecycle of an entry in the queue:
    #     [QUEUED]--(lease)-->[LEASED] -(release)-> out of the queue
    #           ^---(repush)--/
    #
    class QueueWithLease
      include MonitorMixin

      SYNC_TIMEOUT_SEC = 60

      attr_reader :initialized_at, :last_activity_at

      # @param entries [Array<Object>] the entries to enqueue
      def initialize(entries = [])
        # To initialize [MonitorMixin](https://ruby-doc.org/3.2.4/exts/monitor/MonitorMixin.html)
        super()
        @entries = entries.dup
        @leased = {}
        @completed = Set.new
        @initialized_at = Time.now
      end

      # @return [Object] the next entry in the queue
      def lease
        loop do
          sleep 0.1

          entry = synchronize_with_timeout { entries.pop }
          next unless entry

          next if completed?(entry)

          record_lease(entry)
          return entry
        end
      end

      # It's only necessary to remove the entry from the list of leased ones, and
      # this have to be done atomically with pushing to the queue to avoid race
      # conditions when the entry is released by another thread, or there's an
      # attempt to lease it and we release it immediately after.
      #
      # @param entry [String]
      def repush(entry)
        synchronize_with_timeout do
          leased.delete(entry)

          # We want to insert an entry before the last one, so it won't be leased again with the same worker
          # If there is no last entry, we just push it to the end
          entries.insert(entries.empty? ? -1 : -2, entry)
        end
      end

      # @param entry [String]
      # @return [NilClass, Set<String>] `nil` if was already completed
      def release(entry)
        return if completed?(entry)

        synchronize_with_timeout do
          leased.delete(entry)
          completed.add(entry)
        end
      end

      # @param entry [String]
      # @return [TrueClass, FalseClass] `true` if `entry` was already completed
      def completed?(entry)
        synchronize_with_timeout { completed.include?(entry) }
      end

      # @return [TrueClass, FalseClass] `true` if there is no more enqueued or leased entries
      def empty?
        size.zero?
      end

      # @return [Integer] amount of not completed entries
      def size
        synchronize_with_timeout { leased.size + entries.size }
      end

      # @return [Integer] amount of completed entries
      def completed_size
        completed.size
      end

      # @api private
      # @return [Integer] amount of leased entries
      def leased_size
        leased.size
      end

      # @api private
      # Iterate over leased entries
      def select_leased(...)
        synchronize_with_timeout { leased.dup.select(...) }
      end

      # @return [Array<String>] Lists of tests in the queue
      def entries_list
        synchronize_with_timeout { entries.dup }
      end

      # @return [TrueClass, FalseClass] `true` if there was already some activity in the queue
      def visited?
        @last_activity_at != nil
      end

      private

      attr_reader :entries, :completed, :leased

      def record_lease(entry)
        synchronize_with_timeout do
          leased[entry] = Time.now
          @last_activity_at = Time.now
        end
      end

      def synchronize_with_timeout(&block)
        Timeout.timeout(SYNC_TIMEOUT_SEC) do
          synchronize do
            yield block
          end
        end
      rescue Timeout::Error
        raise 'Timeout while waiting for synchronization (deadlock)!'
      end
    end
  end
end

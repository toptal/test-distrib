module DistribCore
  module Leader
    # Default strategy to manage retries of tests.
    class ErrorHandler
      attr_accessor :retryable_exceptions, :retry_attempts, :fatal_worker_failures, :failed_workers_threshold
      attr_reader :failed_workers_count

      def initialize(exception_extractor)
        @retryable_exceptions = []
        @retry_attempts = 0
        @retries_per_test = Hash.new(0)

        @fatal_worker_failures = []
        @failed_workers_threshold = 0
        @failed_workers_count = 0

        @exception_extractor = exception_extractor
      end

      # Decides if the test should be retried.
      #
      # @return [TrueClass, FalseClass]
      def retry_test?(test, results, exception) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
        return false if retries_per_test[test] >= retry_attempts

        exceptions = exception_extractor.failures_of(results)
        exceptions.push(exception) if exception

        failures_causes = exception_extractor.unpack_causes(exceptions)

        return false if failures_causes.empty?

        if retryable_exceptions.empty?
          retries_per_test[test] += 1
          return true
        end

        retried = failures_causes.all? do |causes|
          causes.any? do |cause|
            retryable_exceptions.include?(cause.original_class)
          end
        end

        retries_per_test[test] += 1 if retried

        retried
      end

      # Decides if the exception should be ignored.
      #
      # @return [TrueClass, FalseClass]
      def ignore_worker_failure?(exception)
        self.failed_workers_count += 1

        return false if missing_exception?(exception) || exceeded_failures_threshold? || fatal_failure?(exception)

        true
      end

      private

      attr_reader :exception_extractor, :retries_per_test
      attr_writer :failed_workers_count

      def missing_exception?(exception)
        return false if exception

        logger.debug 'Exception missing'
        true
      end

      def exceeded_failures_threshold?
        if failed_workers_count > failed_workers_threshold
          logger.debug "#{failed_workers_count} failure(s) reported, " \
                       "which exceeds the threshold of #{failed_workers_threshold}"
          return true
        end

        false
      end

      def fatal_failure?(exception)
        failure_causes = exception_extractor.unpack_causes([exception]).first

        cause_class = failure_causes.find do |cause|
          fatal_worker_failures.include?(cause.original_class)
        end&.original_class

        if cause_class
          logger.debug "Fatal failure found: #{cause_class}"
          return true
        end

        false
      end

      def logger
        DistribCore.configuration.broadcaster
      end
    end
  end
end

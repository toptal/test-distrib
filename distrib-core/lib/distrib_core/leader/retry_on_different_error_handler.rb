module DistribCore
  module Leader
    # Only retry if the error is different.
    class RetryOnDifferentErrorHandler < ErrorHandler
      def initialize(exception_extractor, retry_limit: 2, repeated_error_limit: 1)
        super(exception_extractor)
        @exceptions_per_test = Hash.new([])
        @retry_limit = retry_limit
        @repeated_error_limit = repeated_error_limit
      end

      def retry_test?(test, results, exception)
        return false if retries_per_test[test] >= retry_limit

        failures_causes = aggregate_failure_causes(exception, results)

        return false if failures_causes.empty? || repeated_error_limit_exceeded?(test, failures_causes)

        exceptions_per_test[test] += failures_causes
        retries_per_test[test] += 1

        true
      end

      private

      attr_reader :exceptions_per_test, :retry_limit, :repeated_error_limit

      def aggregate_failure_causes(exception, results)
        exceptions = exception_extractor.failures_of(results)
        exceptions.push(exception) if exception
        exception_extractor.unpack_causes(exceptions).flatten
      end

      def repeated_error_limit_exceeded?(test, failures_causes)
        failures_causes.any? do |new|
          failures_with_same_exception = exceptions_per_test[test].select do |old|
            old.original_class == new.original_class && old.message == new.message
          end

          failures_with_same_exception.count >= repeated_error_limit
        end
      end
    end
  end
end

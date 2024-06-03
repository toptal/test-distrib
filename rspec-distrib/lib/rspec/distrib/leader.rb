require 'drb/drb'

require 'rspec/distrib'
require 'rspec/distrib/leader/reporter'
require 'rspec/distrib/leader/tests_provider'

module RSpec
  module Distrib
    # Interface exposed over the network that Workers connect to in order to
    # receive spec file names and report back the results to.
    #
    # Transport used is [DRb](https://rubydoc.info/stdlib/drb/DRb)
    class Leader # rubocop:disable Metrics/ClassLength
      include ::DistribCore::Leader
      # Used to interpolate with leader ip in order to generate the actual DRb server URL
      DRB_SERVER_URL = 'druby://%s:8787'.freeze
      # We can't calculate total amount of examples. But we need to provide a big number to prevent warnings
      FAKE_TOTAL_EXAMPLES_COUNT = 1_000_000_000

      class << self
        # Starts the DRb server and Watchdog thread
        #
        # @param seed [Integer] a seed for workers to randomize order of examples
        # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        def start_service(seed = nil)
          files = ::DistribCore::Leader::QueueBuilder.tests
          queue = ::DistribCore::Leader::QueueWithLease.new(files)

          logger.info "#{files.count} files have been enqueued"

          seed ||= rand(0xFFFF) # Mimic how RSpec::Core::Ordering::ConfigurationManager randomizes it
          RSpec.configuration.seed = seed # it is going to be used by reporter

          reporter = Leader::Reporter.new

          leader = new(queue, reporter, seed)

          watchdog = ::DistribCore::Leader::Watchdog.new(queue)
          watchdog.start

          DRb.start_service(DRB_SERVER_URL % '0.0.0.0', leader, RSpec::Distrib.configuration.drb)
          logger.info 'Leader ready'
          ::DistribCore::Metrics.queue_exposed
          DRb.thread.join

          reporter.finish
          RSpec::Distrib.configuration.on_finish&.call

          failed = reporter.failures? || watchdog.failed? || leader.non_example_exception
          count_mismatch = (queue.size + queue.completed_size != files.count)

          if failed || ::DistribCore::ReceivedSignals.any? || count_mismatch
            print_failure_status(reporter, watchdog, leader, queue, count_mismatch)
            Kernel.exit(::DistribCore::ReceivedSignals.any? ? ::DistribCore::ReceivedSignals.exit_code : 1)
          else
            logger.info "Build succeeded. Files processed: #{queue.completed_size}"
          end
        end
        # rubocop:enable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity

        private

        # rubocop:disable Metrics/AbcSize
        def print_failure_status(reporter, watchdog, leader, queue, count_mismatch)
          logger.info 'Build failed'
          logger.debug(::DistribCore::ReceivedSignals.message) if ::DistribCore::ReceivedSignals.any?
          logger.debug 'Reporter failed' if reporter.failures?
          logger.debug 'Watchdog failed' if watchdog.failed?
          logger.debug 'Non example exception' if leader.non_example_exception
          logger.debug "Files completed: #{queue.completed_size}"
          logger.debug "Files left: #{queue.size}" if queue.size
          logger.warn("Amount of processed files doesn't match amount of enqueued files") if count_mismatch
        end
        # rubocop:enable Metrics/AbcSize
      end

      # Object shared through DRb is open for any calls. Including eval calls
      # A simple way to prevent it - undef
      undef :instance_eval
      undef :instance_exec

      attr_reader :seed, :non_example_exception

      def initialize(queue, reporter, seed)
        @queue = queue
        @reporter = reporter
        @seed = seed
        logger.info "Using seed #{@seed}"
      end

      # Get the next spec from the queue
      # @return [String] spec file name
      # @example
      #   leader.next_file_to_run # => 'spec/services/user_service_spec.rb'
      drb_callable def next_file_to_run
        ::DistribCore::Metrics.test_taken

        queue.lease.tap do |file|
          logger.debug "Serving #{file}"
        end
      end

      # Report example group results for a spec file
      #
      # @param file_path [String] ex: './spec/services/user_service_spec.rb'
      # @param example_groups [Array<RSpec::Distrib::ExampleGroup>]
      # @param exception [RSpec::Distrib::
      # @see RSpec::Distrib::ExampleGroup
      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
      drb_callable def report_file(file_path, example_groups, exception = nil)
        message = "Reported #{file_path} with #{example_groups.count} example groups"
        message += " and exception #{exception.original_class}" if exception
        logger.debug message

        return if queue.completed?(file_path)

        if RSpec::Distrib.configuration.error_handler.retry_test?(file_path, example_groups, exception)
          logger.debug("Retrying #{file_path}")
          will_be_retried = true
          queue.repush(file_path)
          example_groups.each { |example_group| reporter.report(example_group, will_be_retried: true) }
          return
        end

        RSpec.configuration.loaded_spec_files << File.expand_path(file_path)

        example_groups.each { |example_group| reporter.report(example_group) }

        handle_failed_worker(exception, file_path) if exception
        nil
      ensure
        queue.release(file_path) unless will_be_retried
        log_completed_percent
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength

      # Notifies non example error to RSpec reporter and stops the service.
      # If the error occurs in one worker, it's likely something that will break
      # all workers, like a SyntaxError while loading some file, so it does
      # not make sense to continue executing.
      drb_callable def notify_non_example_exception(exception, context_description)
        logger.info("Worker failed with non_example_exception #{exception.original_class}")

        return if RSpec::Distrib.configuration.error_handler.ignore_worker_failure?(exception)

        logger.info("Leader will stop since worker failed with non_example_exception #{exception.original_class}")

        reporter.notify_non_example_exception(exception, context_description)

        handle_non_example_exception

        nil
      end

      drb_callable def report_worker_configuration_error(exception)
        logger.info "Worker failed during startup with #{exception.original_class}"

        return if RSpec::Distrib.configuration.error_handler.ignore_worker_failure?(exception)

        handle_failed_worker(exception)
        nil
      end

      private

      attr_reader :queue, :reporter

      def handle_failed_worker(exception, file = nil)
        message = "Leader will stop since worker failed with #{exception.original_class}"
        message += " on file #{file}:" if file
        message += "\n#{exception.message}"
        logger.error message
        logger.debug exception.backtrace&.join("\n")
        logger.debug exception.cause.inspect if exception.cause

        handle_non_example_exception
      end

      def handle_non_example_exception
        @non_example_exception = true
        DRb.current_server.stop_service
      end

      def log_completed_percent # rubocop:disable Metrics/AbcSize
        @logged_percents ||= []
        log_every = 10

        completed_percent = (queue.completed_size.to_f / (queue.size + queue.completed_size) * 100).to_i
        bucket = completed_percent / log_every * log_every # convert 35 to 30

        return if @logged_percents.include?(bucket)

        @logged_percents << bucket

        logger.debug "Completed: #{completed_percent}%"
      end
    end
  end
end

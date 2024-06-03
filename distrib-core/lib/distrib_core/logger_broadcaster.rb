require 'logger'

module DistribCore
  # Broadcasts logs to multiple loggers.
  class LoggerBroadcaster < Logger
    private :level, :level=, :progname, :progname=, :datetime_format, :datetime_format=,
            :formatter, :formatter=

    def initialize(loggers)
      super(nil)
      @loggers = loggers
    end

    def add(severity, message = nil, progname = nil)
      @loggers.each do |target|
        target.add(severity, message, progname)
      end
    end

    def <<(message)
      @loggers.each { |logger| logger << message }
    end

    def close
      @loggers.each(&:close)
    end

    def reopen(_logdev = nil)
      @loggers.each(&:reopen)
    end
  end
end

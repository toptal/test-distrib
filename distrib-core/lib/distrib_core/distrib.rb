module DistribCore
  # This module is used to define common methods on root classes.
  module Distrib
    # Call to prepare configuration.
    #
    # @see DistribCore::Configuration
    def configure(...)
      configuration.instance_eval(...)
    end

    # Set kind of the current instance.
    #
    # @param kind [Symbol] `:leader` or `:worker` only
    def kind=(kind)
      raise("Mode is already set: #{kind}") if @kind

      kind = kind&.to_sym

      raise(ArgumentError, 'Invalid kind, should be `leader` or `worker`') unless %i[leader worker].include?(kind)

      @kind = kind
    end

    # @return kind of current instance. `:leader` or `:worker`
    #
    # @raise [RuntimeError] if kind is not set
    def kind
      @kind || raise('kind is not set')
    end

    # @return [TrueClass, FalseClass] `true` when `kind` is `:leader`
    def leader?
      kind == :leader
    end

    # @return [TrueClass, FalseClass] true when `kind` is `:worker`
    def worker?
      kind == :worker
    end
  end
end

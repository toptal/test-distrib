# frozen_string_literal: true

module FeaturesParser
  # Registry with Scenario and ScenarioOutline examples.
  #
  # It contains a map of normalized names of a Scenario (or
  # ScenarioOutline example) to {Scenario} objects.
  # Guarantees uniqueness of Scenario's name and ScenarioOutline
  # example's values inside its Feature.
  # Primarily used for mapping a subset of scenarios to their
  # executable format (<path>:<line>)
  class Catalog
    def initialize
      @catalog = {}
      @parser = ScenarioParser.new(catalog: self)
    end

    def parse(files)
      @parser.parse(files)

      self
    end

    def register(scenario)
      validate_uniqueness!(scenario)
      @catalog[scenario.normalized_name] = scenario
    end

    def reset
      @catalog = {}
    end

    def names
      @catalog.keys
    end

    def executable_paths
      @catalog.values.map(&:executable_path)
    end

    def empty?
      @catalog.empty?
    end

    # @param [Array<String>] passed_names scenario names
    def executable_paths_for(passed_names)
      unknown_names = passed_names - names
      raise KeyError, "Unknown scenarios passed: #{unknown_names}." if unknown_names.any?

      @catalog.values_at(*passed_names).map(&:executable_path)
    end

    # @param [Array<String>] passed_paths executable paths
    def names_for(passed_paths)
      passed_paths.map do |path|
        @catalog.find { |_name, feature| feature.executable_path == path }.first
      end.compact
    end

    private

    # Validates uniqueness of Scenario name across the Feature
    #
    # @param [Scenario] scenario
    # @raise [KeyError]
    def validate_uniqueness!(scenario)
      existing_scenario = @catalog[scenario.normalized_name]
      return unless existing_scenario
      return if scenario.executable_path == existing_scenario.executable_path

      message = "Trying to add #{scenario.normalized_name} from #{scenario.executable_path}, " \
                "but it is already defined in #{@catalog[scenario.normalized_name].executable_path}"

      raise KeyError, message if @catalog[scenario.normalized_name]
    end
  end
end

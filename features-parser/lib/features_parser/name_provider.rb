# frozen_string_literal: true

require_relative 'example'
require_relative 'outline'
require_relative 'feature'
require_relative 'scenario'

module FeaturesParser
  # Provides normalized name for given Cucumber object.
  #
  # Used primarily to keep report keys' naming scheme
  # in sync with logic of {FeaturesParser::ScenarioParser}
  #
  # @attr_reader [Cucumber::RunningTestCase::ScenarioOutlineExample] object
  class NameProvider
    attr_reader :object

    # @param [Cucumber::RunningTestCase::ScenarioOutlineExample,
    #   Cucumber::RunningTestCase::Scenario] object a Cucumber object representing
    #   Scenario or ScenarioOutline Example
    def initialize(object)
      @object = object
    end

    def normalized_name
      scenario_or_example = object.outline? ? example : scenario
      scenario_or_example.normalized_name
    end

    private

    def example
      cells = object.cell_values.map { |value| Cucumber::Messages::TableCell.new(value:) }

      table_row = Cucumber::Messages::TableRow.new(
        location: object.location,
        cells:
      )

      Example.new(outline, table_row)
    end

    def outline
      outline = Cucumber::Messages::Scenario.new(
        name: clean_outline_name(object.name),
        location: object.location,
        keyword: 'Scenario Outline'
      )

      Outline.new(feature, outline)
    end

    def feature
      feature = Cucumber::Messages::Feature.new(
        name: object.feature.name,
        location: object.feature.location
      )

      Feature.new(feature, object.feature.location.file)
    end

    def scenario
      scenario = Cucumber::Messages::Scenario.new(
        name: object.name,
        location: object.location,
        keyword: 'Scenario'
      )

      Scenario.new(feature, scenario)
    end

    def clean_outline_name(name)
      return name unless /\(#\d+\)$/.match?(name)

      name[/(.*),/, 1]
    end
  end
end

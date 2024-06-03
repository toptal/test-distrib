# frozen_string_literal: true

require_relative 'name_normalizer'

module FeaturesParser
  # A value object representing Gherkin's Scenario.
  #
  # @attr_reader [String] name name of the Scenario
  # @attr_reader [String] line executable line number
  #   of the Scenario
  class Scenario
    attr_reader :name, :line

    # @param [Feature] feature
    # @param [Hash] scenario_ast AST tree provided by gherkin gem
    def initialize(feature, scenario_ast)
      check_input_ast!(scenario_ast)

      @name = scenario_ast.name
      @line = scenario_ast.location.line
      @feature = feature
    end

    def check_input_ast!(ast)
      raise "Incorrect node supplied: #{ast.class}" unless ast.is_a?(Cucumber::Messages::Scenario)
      raise "Incorrect node supplied: #{ast.keyword}" if ast.keyword != 'Scenario'
    end

    def normalized_name
      @normalized_name ||= [@feature.normalized_name, NameNormalizer.normalize(name)].join('/')
    end

    def executable_path
      "#{@feature.executable_path}:#{line}"
    end
  end
end

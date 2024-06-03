# frozen_string_literal: true

require_relative 'scenario'

module FeaturesParser
  # A value object representing Gherkin's Scenario Outline.
  class Outline < Scenario
    def check_input_ast!(ast)
      raise "Incorrect node supplied: #{ast.class}" unless ast.is_a?(Cucumber::Messages::Scenario)
      raise "Incorrect node supplied: #{ast.keyword}" if ast.keyword != 'Scenario Outline'
    end
  end
end

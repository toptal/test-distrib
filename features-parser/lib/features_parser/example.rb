# frozen_string_literal: true

require_relative 'name_normalizer'

module FeaturesParser
  # A value object representing Gherkin's ScenarioOutline Example.
  #
  # @!attribute [r] outline
  #   @return [Outline] ScenarioOutline object
  #
  # @!attribute [r] executable_path
  #   @return [String] path to the file with this feature
  class Example
    attr_reader :outline, :line

    # @param [Outline] outline ScenarioOutline object
    # @param [Hash] ast AST tree provided by gherkin gem
    def initialize(outline, ast)
      raise "Incorrect node supplied: #{ast.class}" unless ast.is_a?(Cucumber::Messages::TableRow)

      @outline = outline
      @line = ast.location.line
      @cells = normalize_cells(ast.cells)
    end

    def normalized_name
      @normalized_name ||= [outline.normalized_name, @cells.join('|')].join('/')
    end

    def executable_path
      @executable_path ||= outline.executable_path.gsub(/:\d+$/, ":#{line}")
    end

    private

    def normalize_cells(ast)
      ast.map { |cell| NameNormalizer.normalize(cell.value) }
    end
  end
end

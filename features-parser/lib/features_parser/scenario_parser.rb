# frozen_string_literal: true

require_relative 'feature'
require_relative 'scenario'
require_relative 'outline'
require_relative 'example'
require_relative 'catalog'
require 'gherkin'

module FeaturesParser
  # Transforms an array of `*.feature` paths, reads them,
  # and returns normalized representation of Scenario and
  # ScenarioOutline example stanzas in given files.
  #
  # Parsed items will be automatically registered in {Catalog} class.
  #
  # We need this information so we can:
  # 1) filter out non-existing scenarios from report
  # 2) add unknown (according to report) scenarios for leftover distributor
  # 3) map further parsed items to their executable representation "<path>:<line>"
  # Requirements: gem 'gherkin'
  class ScenarioParser
    ParserError = Class.new(StandardError)

    def initialize(catalog: Catalog.new)
      @parser = Gherkin::Parser.new
      @catalog = catalog
    end

    def parse(files)
      files.flat_map do |file|
        parse_file(file)
      end
    end

    private

    attr_reader :parser, :catalog

    def parse_file(file)
      ast = create_ast(file)

      feature = Feature.new(ast.feature, file)
      scenarios = parse_scenarios(ast.feature, feature)
      examples = parse_examples(ast.feature, feature)

      results = scenarios + examples

      register(results)

      results.map(&:normalized_name)
    end

    def create_ast(file)
      parser.parse(File.read(file))
    rescue StandardError => e
      raise ParserError, "Filename: #{file}\n#{e.message}"
    end

    def parse_scenarios(ast, feature)
      filter_by_keyword(ast, 'Scenario').map do |scenario|
        Scenario.new(feature, scenario)
      end
    end

    def parse_examples(ast, feature)
      filter_by_keyword(ast, 'Scenario Outline').flat_map do |scenario|
        outline = Outline.new(feature, scenario)

        scenario.examples.flat_map do |examples|
          examples.table_body.map do |example|
            Example.new(outline, example)
          end
        end
      end
    end

    def filter_by_keyword(ast, keyword)
      ast.children.filter_map { |child| child.scenario if child.scenario&.keyword == keyword }
    end

    def register(items)
      items.each { |item| catalog.register(item) }
    end
  end
end

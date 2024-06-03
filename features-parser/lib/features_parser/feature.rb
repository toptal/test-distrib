# frozen_string_literal: true

require_relative 'name_normalizer'

module FeaturesParser
  # A value object representing Gherkin's Feature.
  #
  # @attr_reader [String] name name of the Feature
  # @attr_reader [String] executable_path path to the file
  #   with this feature
  class Feature
    attr_reader :name, :executable_path

    # @param [Hash] ast AST tree provided by gherkin gem
    # @param [String] path full path to a file containing feature
    def initialize(ast, path)
      raise "Incorrect node supplied: #{ast.class}" unless ast.is_a?(Cucumber::Messages::Feature)

      @name = ast.name
      @executable_path = path
    end

    def normalized_name
      @normalized_name ||= NameNormalizer.normalize(name)
    end
  end
end

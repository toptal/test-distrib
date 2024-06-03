# frozen_string_literal: true

require 'active_support/core_ext/object/blank'

# Main module for the gem.
module FeaturesParser
end

require_relative 'features_parser/version'

require_relative 'features_parser/catalog'
require_relative 'features_parser/example'
require_relative 'features_parser/feature'
require_relative 'features_parser/name_normalizer'
require_relative 'features_parser/name_provider'
require_relative 'features_parser/outline'
require_relative 'features_parser/scenario_parser'
require_relative 'features_parser/scenario'

# frozen_string_literal: true

require 'active_support/core_ext/object/blank'

module FeaturesParser
  # Normalizes and cleans passed string.
  #
  # Replaces special characters in a string,
  # so that it may be used as part of a 'pretty' identifier.
  #
  # "Donald E. Knuth" becomes "donald-e-knuth"
  module NameNormalizer
    def self.normalize(string, sep = '-')
      normalized_string = string.dup

      # Turn unwanted chars into the separator
      normalized_string.gsub!(/[^\w-]+/i, sep)

      if sep.present?
        re_sep = Regexp.escape(sep)

        # No more than one of the separator in a row
        # plus remove leading/trailing separator
        normalized_string = normalized_string.split(/(?:#{re_sep})+/).reject(&:empty?).join(sep)
      end

      normalized_string.downcase
    end
  end
end

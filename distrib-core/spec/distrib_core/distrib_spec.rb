# frozen_string_literal: true

require 'distrib_core/spec/distrib'

RSpec.describe DistribCore::Distrib do
  subject(:root) do
    Class.new do
      extend DistribCore::Distrib

      def self.configuration
        @configuration ||= Class.new do
          include DistribCore::Configuration
        end.new
      end
    end
  end

  include_examples 'DistribCore root module'
end

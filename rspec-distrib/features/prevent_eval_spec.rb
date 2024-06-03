# frozen_string_literal: true

require_relative 'feature_helper'

RSpec.describe 'Prevent eval' do
  include_context 'base pipeline'

  specify do
    run_distrib(:prevent_eval)

    expect(leader.output).not_to include 'HACKED!'
  end
end

# frozen_string_literal: true

require_relative 'feature_helper'

RSpec.describe 'Passing specs' do
  include_context 'base pipeline'

  specify do
    run_distrib(:passing, workers_count: 2)

    expect(leader.output).to include '2 files have been enqueued'
    expect(leader.output).to match(/custom_metadata_field=>"present"/)
    expect(leader.output).to match(/0 failures$/)

    expect(worker_outputs).to include match(/1 example/)
    expect(worker_outputs).to include match(/2 examples/)
    expect(worker_outputs).to include match(/0 failures/)

    common_checks
  end
end

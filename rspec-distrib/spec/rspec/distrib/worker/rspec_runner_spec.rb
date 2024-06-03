# frozen_string_literal: true

require 'tempfile'

RSpec.describe RSpec::Distrib::Worker::RSpecRunner do # rubocop:disable RSpec/FilePath, RSpec/SpecFilePathFormat
  include RSpec::Support::InSubProcess

  # restore the original value to prevent leaking leader double to other examples
  # see described_class initializer setting it to global RSpec.configuration
  around do |example|
    old_configuration = RSpec.configuration
    example.run
  ensure
    RSpec.configuration = old_configuration
  end

  let(:leader) { instance_double(RSpec::Distrib::Leader, seed: 1234) }

  it 'gets seed from the leader' do
    # Isolate seed setting to configuration of this example only.
    in_sub_process_if_possible do
      runner = described_class.new(leader)
      expect(runner.configuration.seed).to eq(1234)
    end
  end

  context 'when running' do
    let(:temp_file) { Tempfile.new }

    before do
      allow(leader).to receive(:report_file)
      allow(leader).to receive(:next_file_to_run).and_return(temp_file.path, nil)
    end

    after { temp_file.unlink }

    def mock_reporter
      report = double.as_null_object
      allow(report).to receive(:examples).and_return([])

      reporter = double.as_null_object
      allow(reporter).to receive(:report).and_yield(report)

      reporter
    end

    it "consumes leader's queue" do
      in_sub_process_if_possible do
        RSpec.configuration.reset_reporter
        allow(RSpec.configuration).to receive(:reporter).and_return(mock_reporter)

        expect(leader).to receive(:next_file_to_run).and_return(temp_file.path).once

        described_class.new(leader).run($stdout, $stdout)
      end
    end
  end

  describe '.run_from_leader' do
    let(:leader) { instance_double(DRbObject) }
    let(:runner) { instance_double(described_class) }

    it 'initializes a runner and calls #run' do
      allow(DRbObject).to receive(:new_with_uri)
        .with(RSpec::Distrib::Leader::DRB_SERVER_URL % 'leader_ip')
        .and_return(leader)
      expect(described_class).to receive(:new).with(leader).and_return(runner)
      expect(runner).to receive(:run)
      described_class.run_from_leader('leader_ip')
    end
  end

  describe '#load_spec_file' do
    let(:leader) { instance_double(RSpec::Distrib::Leader, seed: 42) }
    let(:runner) { described_class.new(leader) }

    it 'sets color_mode' do
      allow(runner.configuration).to receive(:load_spec_files)
      expect(runner.configuration.color_mode).to eq(:automatic)

      RSpec::Distrib.configuration.worker_color_mode = :off
      runner.__send__ :load_spec_file, 'path/to/spec.rb'
      expect(runner.configuration.color_mode).to eq(:off)

      RSpec::Distrib.configuration.worker_color_mode = :on
      runner.__send__ :load_spec_file, 'path/to/spec.rb'
      expect(runner.configuration.color_mode).to eq(:on)

      RSpec::Distrib.configuration.worker_color_mode = nil
      runner.__send__ :load_spec_file, 'path/to/spec.rb'
      expect(runner.configuration.color_mode).to eq(:automatic)
    end
  end
end

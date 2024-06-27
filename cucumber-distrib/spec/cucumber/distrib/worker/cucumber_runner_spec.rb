# frozen_string_literal: true

RSpec.describe Cucumber::Distrib::Worker::CucumberRunner do
  include RSpec::Support::InSubProcess

  subject(:runner) { described_class.new(leader) }

  let(:leader) { instance_double(Cucumber::Distrib::Leader, profiles: %w[p1 p2]) }

  it 'gets profiles from the leader' do
    cli = instance_double(Cucumber::Cli::Main, configuration: { profiles: %w[p1 p2] })
    expect(Cucumber::Cli::Main).to receive(:new).with(%w[-p p1 -p p2]).and_return(cli)
    expect(runner.configuration.profiles).to eq(%w[p1 p2])
  end

  it 'uses custom EventBus' do
    cli = instance_double(Cucumber::Cli::Main, configuration: {})
    allow(Cucumber::Cli::Main).to receive(:new).and_return(cli)
    expect(runner.configuration.event_bus).to be_an_instance_of(Cucumber::Distrib::Worker::EventBus)
  end

  context 'when running' do
    let(:temp_file) { 'some_file_path' }

    before do
      cli = instance_double(Cucumber::Cli::Main, configuration: {})
      allow(Cucumber::Cli::Main).to receive(:new).and_return(cli)
      allow(leader).to receive(:report_test).and_return('result')
    end

    it "consumes leader's queue" do
      expect(leader).to receive(:next_test_to_run).and_return(temp_file, nil)
      # rubocop:disable RSpec/AnyInstance this cop is not essential here
      expect_any_instance_of(Cucumber::Runtime::SupportCode).to receive(:load_files!)
      # rubocop:enable RSpec/AnyInstance
      runner
      # rubocop:disable RSpec/SubjectStub mock external methods which comes from original Cucumber::Runner
      expect(runner).to receive(:compile)
      expect(runner).to receive(:features).and_return([])
      expect(runner).to receive(:filters).and_return([])
      # rubocop:enable RSpec/SubjectStub
      allow(runner.configuration.event_bus).to receive(:events_for_leader) do # rubocop:disable RSpec/ReturnFromStub
        ['event']
      end
      expect(Cucumber::Distrib::Events).to receive(:convert).with('event').and_return('converted_event')
      expect(leader).to receive(:report_test).with(temp_file, ['converted_event'], nil).once
      expect(runner.configuration).to receive(:notify).with(:test_reported, 'result')
      expect(runner.configuration).to receive(:notify).with(:test_run_finished)
      runner.run!
    end
  end

  describe '.run_from_leader' do
    let(:leader) { instance_double(DRbObject) }
    let(:runner) { instance_double(described_class) }

    it 'initializes a runner and calls #run' do
      expect(DRbObject).to receive(:new_with_uri)
        .with(Cucumber::Distrib::Leader::DRB_SERVER_URL % 'leader_ip')
        .and_return(leader)

      expect(described_class).to receive(:new).with(leader).and_return(runner)
      expect(runner).to receive(:run!)
      described_class.run_from_leader('leader_ip')
    end
  end
end

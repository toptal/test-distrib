# frozen_string_literal: true

RSpec.describe FeaturesParser::Catalog do
  subject(:catalog) { described_class.new }

  let(:scenario1) do
    instance_double(
      FeaturesParser::Scenario,
      normalized_name: 'some-feature/scenario1',
      executable_path: 'some-feature.feature:5'
    )
  end

  let(:scenario2) do
    instance_double(
      FeaturesParser::Scenario,
      normalized_name: 'another-feature/scenario2',
      executable_path: 'another-feature.feature:7'
    )
  end

  let(:scenarios) { [scenario1, scenario2] }

  before do
    catalog.reset

    catalog.register(scenario1)
    catalog.register(scenario2)
  end

  describe 'validate_uniqueness' do
    context 'when file is the same' do
      it 'allows same scenario to be registered twice' do
        catalog.register(scenario1)
      end
    end

    context 'when file is different' do
      it 'fails if scenario with the same name is registered twice' do
        same_name_different_file = instance_double(
          FeaturesParser::Scenario,
          normalized_name: scenario1.normalized_name,
          executable_path: 'different-feature.feature:10'
        )
        expect { catalog.register(same_name_different_file) }.to raise_error KeyError
      end
    end
  end

  it 'returns names of all registered scenarios' do
    scenario_names = scenarios.map(&:normalized_name)
    expect(catalog.names).to eq scenario_names
  end

  describe 'executable paths' do
    it 'returns executable paths' do
      scenario_paths = scenarios.map(&:executable_path)
      expect(catalog.executable_paths).to eq scenario_paths
    end

    it 'filters executable paths' do
      names = [scenario1.normalized_name]
      expect(catalog.executable_paths_for(names)).to eq [scenario1.executable_path]
    end

    it 'fails on non-registered name' do
      unknown_scenario = 'pants'
      expect { catalog.executable_paths_for([unknown_scenario]) }.to raise_error KeyError
      expect { catalog.executable_paths_for([scenario1, unknown_scenario]) }.to raise_error KeyError
    end
  end
end

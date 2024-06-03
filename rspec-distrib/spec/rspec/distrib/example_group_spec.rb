# frozen_string_literal: true

RSpec.describe RSpec::Distrib::ExampleGroup do
  subject(:example_group) { described_class.new(rspec_example_group, parent_example_group) }

  let(:rspec_example_group) do
    class_double(RSpec::Core::ExampleGroup,
                 metadata:,
                 children: [],
                 filtered_examples: [])
      .as_null_object
  end

  let(:parent_example_group) do
    class_double(described_class)
      .as_null_object
  end

  let(:metadata) { {} }

  describe 'metadata delegation' do
    let(:metadata) do
      {
        described_class: 'Foo',
        file_path: 'foo.rb',
        location: 'foo.rb:42'
      }
    end

    it 'delegates to metadata' do
      expect(example_group.described_class).to eq('Foo')
      expect(example_group.file_path).to eq('foo.rb')
      expect(example_group.location).to eq('foo.rb:42')
    end
  end

  describe '#top_level?' do
    context 'when parent_group exists' do
      it 'returns false' do
        expect(example_group.top_level?).to be(false)
      end
    end

    context 'when parent_group does not exist' do
      let(:parent_example_group) { nil }

      it 'returns true' do
        expect(example_group.top_level?).to be(true)
      end
    end
  end

  describe 'parent_groups' do
    let(:parent_example_group) do
      described_class.new(rspec_example_group, parent_2)
    end
    let(:parent_2) do
      described_class.new(rspec_example_group)
    end

    it 'returns all parent_groups' do
      expect(example_group.parent_groups).to eq([example_group, parent_example_group, parent_2])
    end
  end
end

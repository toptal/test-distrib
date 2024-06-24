# frozen_string_literal: true

RSpec.describe DistribCore::DRbHelper do # rubocop:disable RSpec/SpecFilePathFormat
  let(:broadcaster) { instance_double(DistribCore::LoggerBroadcaster) }

  before do
    configuration = instance_double(DistribCore::Configuration, broadcaster:)
    allow(DistribCore::Configuration).to receive(:current).and_return(configuration)
  end

  describe '.drb_unknown?' do
    it 'returns false for regular object' do
      expect(described_class.drb_unknown?(Object.new, 1)).to be false
      expect(described_class.drb_unknown?('asd', StandardError.new('asd'))).to be false
    end

    it 'returns true and logs error if meet DRb::DRbUnknown' do
      object = nil
      A = Class.new # rubocop:disable Lint/ConstantDefinitionInBlock, RSpec/LeakyConstantDeclaration:
      data = Marshal.dump(A)
      Object.send(:remove_const, :A) # rubocop:disable RSpec/RemoveConst

      begin
        Marshal.load(data) # rubocop:disable Security/MarshalLoad
      rescue StandardError => e
        object = DRb::DRbUnknown.new(e, data)
      end

      expect(broadcaster).to receive(:error).with('Parse error:')
      expect(broadcaster).to receive(:error).with(an_instance_of(ArgumentError))
      expect(broadcaster).to receive(:debug).with(/Can't parse:.*DRbUnknown.*A.*/)
      expect(described_class.drb_unknown?('asd', object, 1)).to be true
    end
  end

  describe '.dump_failed?' do
    it 'returns false if error is not related to unsuccessful dump' do
      expect(described_class.dump_failed?(
               TypeError.new('asd'),
               ['any']
             )).to be false
    end

    it 'returns true and prints info when meet unsuccessful dump' do
      # Failed dump of Proc works fine
      stub_const('A', Class.new do
        attr_accessor :a
      end)

      stub_const('B', Class.new do
        attr_accessor :b
      end)

      object = A.new.tap { |a| a.a = B.new.tap { |b| b.b = -> {} } }

      begin
        error = Marshal.dump(object)
      rescue StandardError => e
        error = e
      end

      expect(broadcaster).to receive(:error).with('Marshal dump error:')
      expect(broadcaster).to receive(:error).with(error)
      expect(broadcaster).to receive(:debug).with(/Cant serialize.*Proc.*in path A@a B@b/)
      expect(described_class.dump_failed?(
               error,
               object
             )).to be true
    end
  end
end

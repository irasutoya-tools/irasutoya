# frozen_string_literal: true

RSpec.describe Irasutoya::Modules::DualLevel do
  let(:has_greeting) do
    Module.new do
      include Irasutoya::Modules::DualLevel

      module Methods
        def greeting
          'hello'
        end
      end
    end
  end

  it 'makes the Methods submodule available as both instance and class methods of the including class' do
    klass = Class.new { include has_greeting }

    expect(klass.new.greeting).to eq('hello')
    expect(klass.greeting).to eq('hello')
  end

  it 'calls through other included hooks via super' do
    other_hook_calls = []
    combined = Module.new do
      include Irasutoya::Modules::DualLevel

      module Methods
        def greeting
          'hi'
        end
      end
    end
    combined.define_singleton_method(:included) do |klass|
      other_hook_calls << klass
      super(klass)
    end

    klass = Class.new { include combined }

    expect(other_hook_calls).to eq([klass])
    expect(klass.new.greeting).to eq('hi')
  end
end

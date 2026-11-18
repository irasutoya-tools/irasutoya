# frozen_string_literal: true

RSpec.describe 'Irasutoya gem metadata' do
  subject(:specification) { Gem::Specification.load(File.expand_path('../irasutoya.gemspec', __dir__)) }

  it 'describes the Ruby library in the summary and description' do
    expect([specification.summary, specification.description]).to all(include('Ruby library for'))
  end

  it 'does not advertise a command-line interface' do
    expect([specification.summary, specification.description].join(' ')).not_to match(/\b(?:CLI|command[- ]line)\b/i)
  end
end

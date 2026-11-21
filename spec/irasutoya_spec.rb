# frozen_string_literal: true

RSpec.describe Irasutoya do
  it 'has a version number' do
    expect(Irasutoya::VERSION).not_to be nil
  end

  it 'declares CGI as a runtime dependency' do
    expect(Gem.loaded_specs.fetch('irasutoya').runtime_dependencies.map(&:name)).to include('cgi')
  end
end

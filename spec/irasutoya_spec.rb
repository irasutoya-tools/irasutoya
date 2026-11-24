# frozen_string_literal: true

RSpec.describe Irasutoya do
  it 'has a version number' do
    expect(Irasutoya::VERSION).not_to be nil
  end

  it 'declares CGI as a runtime dependency' do
    expect(Gem.loaded_specs.fetch('irasutoya').runtime_dependencies.map(&:name)).to include('cgi')
  end

  it 'declares a minimum URI version that provides decode_uri_component' do
    dependencies = Gem.loaded_specs.fetch('irasutoya').runtime_dependencies
    requirement = dependencies.find { |dependency| dependency.name == 'uri' }&.requirement

    expect(requirement).not_to be_nil
    expect(requirement.satisfied_by?(Gem::Version.new('0.12.0'))).to be true
    expect(requirement.satisfied_by?(Gem::Version.new('0.11.1'))).to be false
  end
end

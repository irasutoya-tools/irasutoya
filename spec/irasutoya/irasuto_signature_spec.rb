# frozen_string_literal: true

require 'rbs'

RSpec.describe 'Irasutoya::Irasuto class method signatures' do
  let(:irasuto) { Irasutoya::Irasuto }
  let(:methods) do
    loader = RBS::EnvironmentLoader.new
    loader.add(path: Pathname(__dir__).join('../../sig'))
    environment = RBS::Environment.from_loader(loader).resolve_type_names
    RBS::DefinitionBuilder.new(env: environment).build_singleton(RBS::TypeName.parse('::Irasutoya::Irasuto')).methods
  end

  it 'keeps the random helpers private in Ruby and RBS' do
    helpers = %i[random_api_path random_url]

    expect(irasuto.private_methods).to include(*helpers)
    expect(methods.fetch_values(*helpers).map(&:accessibility)).to eq(%i[private private])
  end

  it 'keeps random and search public in Ruby and RBS' do
    entry_points = %i[random search]

    expect(irasuto.public_methods).to include(*entry_points)
    expect(methods.fetch_values(*entry_points).map(&:accessibility)).to eq(%i[public public])
  end
end

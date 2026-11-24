# frozen_string_literal: true

require 'rbs'

RSpec.describe 'Irasutoya::Irasuto class method signatures' do
  let(:irasuto) { Irasutoya::Irasuto }
  let(:builder) do
    loader = RBS::EnvironmentLoader.new
    loader.add(path: Pathname(__dir__).join('../../sig'))
    environment = RBS::Environment.from_loader(loader).resolve_type_names
    RBS::DefinitionBuilder.new(env: environment)
  end
  let(:methods) { builder.build_singleton(RBS::TypeName.parse('::Irasutoya::Irasuto')).methods }

  it 'allows list parser overrides to omit the thumbnail URL' do
    expect(list_entry_type(return_type(:parse_list_page)).optional_fields).to have_key(:thumbnail_url)
  end

  it 'allows list dispatch to forward overrides that omit the thumbnail URL' do
    array_type = return_type(:list_page_entries).types.find { |type| type.name.to_s == '::Array' }

    expect(list_entry_type(array_type).optional_fields).to have_key(:thumbnail_url)
  end

  it 'allows detail parser overrides to omit categories' do
    expect(return_type(:parse_show_page).optional_fields).to have_key(:categories)
  end

  it 'keeps the random helpers private in Ruby and RBS' do
    helpers = %i[fetch_feed load_initial_random_post load_refreshed_random_post]

    expect(irasuto.private_methods).to include(*helpers)
    expect(methods.fetch_values(*helpers).map(&:accessibility)).to all(eq(:private))
  end

  it 'keeps random and search public in Ruby and RBS' do
    entry_points = %i[random search]

    expect(irasuto.public_methods).to include(*entry_points)
    expect(methods.fetch_values(*entry_points).map(&:accessibility)).to eq(%i[public public])
  end

  def return_type(method_name)
    methods.fetch(method_name).method_types.fetch(0).type.return_type
  end

  def list_entry_type(array_type)
    builder.expand_alias(array_type.args.fetch(0).name)
  end
end

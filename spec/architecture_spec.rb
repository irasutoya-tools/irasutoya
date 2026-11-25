# frozen_string_literal: true

RSpec.describe 'Packaged architecture guide' do
  let(:root) { File.expand_path('..', __dir__) }
  let(:guide) { File.join(root, 'docs/architecture.md') }
  let(:links) { File.read(guide).scan(/^\[([^\]]+)\]: (\S+)$/).to_h }
  let(:gemspec) { Gem::Specification.load(File.join(root, 'irasutoya.gemspec')) }
  let(:files) { gemspec.files }

  it 'points the gemspec homepage and metadata at the canonical repository' do
    repository = 'https://github.com/irasutoya-tools/irasutoya'

    expect(gemspec.homepage).to eq(repository)
    expect(gemspec.metadata['homepage_uri']).to eq(repository)
    expect(gemspec.metadata['source_code_uri']).to eq(repository)
    expect(gemspec.metadata['changelog_uri']).to eq(repository)
  end

  it 'links to the specs and fixtures in the canonical repository' do
    repository = 'https://github.com/irasutoya-tools/irasutoya'
    specs = {
      'listing-spec' => 'incomplete_list_cards_spec.rb',
      'pagination-spec' => 'search_pagination_spec.rb',
      'detail-spec' => 'irasuto_spec.rb',
      'timeout-spec' => 'fetch_timeout_spec.rb',
      'connection-spec' => 'http_connection_spec.rb'
    }
    expected_links = specs.transform_values { |name| "#{repository}/blob/master/spec/irasutoya/#{name}" }
    expect(links).to include(expected_links.merge('fixtures' => "#{repository}/tree/master/spec/files"))
  end

  it 'packages the guide and its relative link targets without specs or fixtures' do
    relative_targets = links.values.grep(%r{^\.\./}).map { |target| target.delete_prefix('../') }

    expect(relative_targets).to include('CONTRIBUTING.md', 'lib/irasutoya/irasuto.rb')
    expect(files).to include('docs/architecture.md', *relative_targets)
    expect(files.grep(%r{^spec/})).to be_empty
  end
end

# frozen_string_literal: true

RSpec.describe Irasutoya::Irasuto do
  let(:query) { '猫' }
  let(:search_url) { "https://www.irasutoya.com/search?q=#{CGI.escape(query)}" }
  let(:next_href) { '/search?q=%E7%8C%AB&updated-max=2018-09-01T12:00:00%2B09:00&start=7&by-date=false' }
  let(:next_url) { "https://www.irasutoya.com#{next_href}" }
  let(:search_uri) { URI.parse(search_url) }
  let(:next_uri) { URI.parse(next_url) }
  let(:first_results) { (1..7).map { |index| "/2018/09/cat-#{index}.html" } }
  let(:next_results) { %w[/2018/09/blog-post_34.html /2018/09/cat-9.html] }

  before do
    next_link = %(<a class="blog-pager-older-link" href="#{CGI.escapeHTML(next_href)}">Next</a>)
    stub_search_page(search_uri, first_results, next_link)
    stub_search_page(next_uri, next_results)
  end

  it 'returns all seven results on the default page without fetching the next page' do
    expect(described_class.search(query: query).map(&:show_url)).to eq(first_results)
    expect(OpenURI).not_to have_received(:open_uri).with(next_uri)
  end

  it 'follows the advertised cursor to the second page' do
    expect(described_class.search(query: query, page: 1).map(&:show_url)).to eq(next_results)
    expect(OpenURI).to have_received(:open_uri).with(next_uri).once
  end

  it 'returns an empty array beyond the last page' do
    expect(described_class.search(query: query, page: 2)).to eq([])
    expect(OpenURI).to have_received(:open_uri).with(next_uri).once
  end

  def stub_search_page(uri, paths, pager = '')
    results = paths.map do |path|
      %(<div class="box"><a href="#{path}">Image</a><a href="#{path}">Cat</a></div>)
    end
    html = "<html><body>#{results.join}#{pager}</body></html>"
    response = double('HTTP response', charset: 'UTF-8', read: html)
    allow(OpenURI).to receive(:open_uri).with(uri).and_yield(response)
  end
end

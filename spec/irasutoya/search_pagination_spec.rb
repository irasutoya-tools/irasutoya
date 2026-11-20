# frozen_string_literal: true

RSpec.describe Irasutoya::Irasuto do
  let(:page_http) { stub_page_http }
  let(:query) { '猫' }
  let(:search_url) { "https://www.irasutoya.com/search?q=#{CGI.escape(query)}" }
  let(:next_href) { '/search?q=%E7%8C%AB&updated-max=2018-09-01T12:00:00%2B09:00&start=7&by-date=false' }
  let(:next_url) { "https://www.irasutoya.com#{next_href}" }
  let(:search_uri) { URI.parse(search_url) }
  let(:next_uri) { URI.parse(next_url) }
  let(:first_results) { (1..7).map { |index| "/2018/09/cat-#{index}.html" } }
  let(:next_results) { %w[/2018/09/blog-post_34.html /2018/09/cat-9.html] }

  before do
    stub_search_page(search_uri, first_results, next_href)
    stub_search_page(next_uri, next_results)
  end

  it 'returns all seven results on the default page without fetching the next page' do
    expect(described_class.search(query: query).map(&:show_url)).to eq(first_results)
    expect(page_http).to have_received(:request_get).with(search_uri.request_uri).once
    expect(page_http).not_to have_received(:request_get).with(next_uri.request_uri)
  end

  it 'follows the advertised cursor to the second page' do
    expect(described_class.search(query: query, page: 1).map(&:show_url)).to eq(next_results)
    expect(page_http).to have_received(:request_get).with(next_uri.request_uri).once
  end

  it 'returns an empty array beyond the last page' do
    expect(described_class.search(query: query, page: 2)).to eq([])
    expect(page_http).to have_received(:request_get).with(next_uri.request_uri).once
  end

  it 'returns no results after one fetch when the older link points to itself' do
    stub_search_page(search_uri, first_results, search_uri.request_uri)

    expect(described_class.search(query: query, page: 100)).to eq([])
    expect(page_http).to have_received(:request_get).with(search_uri.request_uri).once
  end

  it 'returns no results after two fetches when older links form a cycle' do
    stub_search_page(next_uri, next_results, search_url)

    expect(described_class.search(query: query, page: 100)).to eq([])
    expect(page_http).to have_received(:request_get).with(search_uri.request_uri).once
    expect(page_http).to have_received(:request_get).with(next_uri.request_uri).once
  end

  def stub_search_page(uri, paths, older_href = nil)
    results = paths.map do |path|
      %(<div class="box"><a href="#{path}">Image</a><a href="#{path}">Cat</a></div>)
    end
    pager = %(<a class="blog-pager-older-link" href="#{CGI.escapeHTML(older_href)}">Next</a>) if older_href
    html = "<html><body>#{results.join}#{pager}</body></html>"
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    response['Content-Type'] = 'text/html; charset=UTF-8'
    allow(response).to receive(:body).and_return(html)
    allow(response).to receive(:read_body).and_yield(html)
    allow(page_http).to receive(:request_get).with(uri.request_uri).and_yield(response).and_return(response)
  end
end

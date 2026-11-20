# frozen_string_literal: true

RSpec.describe Irasutoya::Irasuto do
  let(:page_http) { stub_page_http }
  let(:query) { '猫' }
  let(:search_url) { "https://www.irasutoya.com/search?q=#{CGI.escape(query)}" }
  let(:next_href) { '/search?q=%E7%8C%AB&updated-max=2018-09-01T12:00:00%2B09:00&start=7&by-date=false' }
  let(:next_url) { "https://www.irasutoya.com#{next_href}" }
  let(:search_uri) { URI.parse(search_url) }
  let(:first_page_uri) { search_uri }
  let(:next_uri) { URI.parse(next_url) }
  let(:first_results) { (1..7).map { |index| "/2018/09/cat-#{index}.html" } }
  let(:next_results) { %w[/2018/09/blog-post_34.html https://www.irasutoya.com/2018/09/cat-9.html] }

  before do
    next_link = %(<a class="blog-pager-older-link" href="#{CGI.escapeHTML(next_href)}">Next</a>)
    stub_search_page(first_page_uri, first_results, next_link)
    stub_search_page(next_uri, next_results)
  end

  it 'returns all seven results on the default page without fetching the next page' do
    expected_urls = first_results.map { |path| "https://www.irasutoya.com#{path}" }
    expect(described_class.search(query: query).map(&:show_url)).to eq(expected_urls)
    expect(page_http).to have_received(:request_get).with(search_uri.request_uri).once
    expect(page_http).not_to have_received(:request_get).with(next_uri.request_uri)
  end

  it 'follows the advertised cursor to the second page' do
    expect(described_class.search(query: query, page: 1).map(&:show_url)).to eq(%w[
      https://www.irasutoya.com/2018/09/blog-post_34.html https://www.irasutoya.com/2018/09/cat-9.html
    ])
    expect(page_http).to have_received(:request_get).with(next_uri.request_uri).once
  end

  it 'fetches the detail page from a root-relative search result' do
    detail_uri = URI.parse('https://www.irasutoya.com/2018/09/cat-1.html')
    stub_html(detail_uri, File.read('spec/files/show.html'))

    expect(described_class.search(query: query).first.fetch_irasuto).to have_attributes(
      url: detail_uri.to_s, title: '太った少年のイラスト（肥満）'
    )
    expect(page_http).to have_received(:request_get).with(detail_uri.request_uri).once
  end

  it 'fetches the detail page from an absolute search result' do
    detail_uri = URI.parse('https://www.irasutoya.com/2018/09/cat-9.html')
    stub_html(detail_uri, File.read('spec/files/show.html'))

    expect(described_class.search(query: query, page: 1).last.fetch_irasuto).to have_attributes(
      url: detail_uri.to_s, title: '太った少年のイラスト（肥満）'
    )
  end

  it 'returns an empty array beyond the last page' do
    expect(described_class.search(query: query, page: 2)).to eq([])
    expect(page_http).to have_received(:request_get).with(next_uri.request_uri).once
  end

  context 'when the search redirects to another directory' do
    let(:first_page_uri) { URI.join(search_url, '/archive/cats/index.html') }
    let(:next_href) { 'older.html' }
    let(:next_url) { 'https://www.irasutoya.com/archive/cats/older.html' }
    let(:next_results) { %w[cat-8.html https://www.irasutoya.com/2018/09/cat-9.html] }

    before do
      response = Net::HTTPFound.new('1.1', '302', 'Found')
      response['Location'] = first_page_uri.request_uri
      response['Content-Length'] = '0'
      allow(response).to receive(:read_body)
      allow(page_http).to receive(:request_get).with(search_uri.request_uri).and_yield(response).and_return(response)
    end

    it 'fetches the older page relative to the redirected page and returns its results' do
      expect(described_class.search(query: query, page: 1).map(&:show_url)).to eq(%w[
        https://www.irasutoya.com/archive/cats/cat-8.html https://www.irasutoya.com/2018/09/cat-9.html
      ])
      expect(page_http).to have_received(:request_get).with(first_page_uri.request_uri).once
      expect(page_http).to have_received(:request_get).with(next_uri.request_uri).once
    end
  end

  def stub_search_page(uri, paths, pager = '')
    results = paths.map do |path|
      %(<div class="box"><a href="#{path}">Image</a><a href="#{path}">Cat</a></div>)
    end
    stub_html(uri, "<html><body>#{results.join}#{pager}</body></html>")
  end

  def stub_html(uri, html)
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    response['Content-Type'] = 'text/html; charset=UTF-8'
    allow(response).to receive(:body).and_return(html)
    allow(response).to receive(:read_body).and_yield(html)
    allow(page_http).to receive(:request_get).with(uri.request_uri).and_yield(response).and_return(response)
  end
end

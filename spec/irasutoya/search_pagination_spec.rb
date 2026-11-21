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
  let(:thumbnail_url) { 'https://1.bp.blogspot.com/example/s72-c/cat.png' }

  before do
    stub_search_page(first_page_uri, first_results, next_href)
    stub_search_page(next_uri, next_results)
  end

  it 'returns all seven results on the default page without fetching the next page' do
    expected_urls = first_results.map { |path| "https://www.irasutoya.com#{path}" }
    expect(described_class.search(query: query).map(&:show_url)).to eq(expected_urls)
    expect(page_http).to have_received(:request_get).with(search_uri.request_uri).once
    expect(page_http).not_to have_received(:request_get).with(next_uri.request_uri)
  end

  it 'follows the advertised cursor and returns links with thumbnails from the second page' do
    links = described_class.search(query: query, page: 1)

    expect(links.map(&:show_url)).to eq(%w[
      https://www.irasutoya.com/2018/09/blog-post_34.html https://www.irasutoya.com/2018/09/cat-9.html
    ])
    expect(links.map(&:thumbnail_url)).to eq([thumbnail_url, thumbnail_url])
    expect(page_http).to have_received(:request_get).with(next_uri.request_uri).once
  end

  it 'fetches the detail page from a root-relative search result' do
    detail_uri = URI.parse('https://www.irasutoya.com/2018/09/cat-1.html')
    stub_html(page_http, File.read('spec/files/show.html'), path: detail_uri.request_uri)

    expect(described_class.search(query: query).first.fetch_irasuto).to have_attributes(
      url: detail_uri.to_s, title: '太った少年のイラスト（肥満）'
    )
    expect(page_http).to have_received(:request_get).with(detail_uri.request_uri).once
  end

  it 'fetches the detail page from an absolute search result' do
    detail_uri = URI.parse('https://www.irasutoya.com/2018/09/cat-9.html')
    stub_html(page_http, File.read('spec/files/show.html'), path: detail_uri.request_uri)

    expect(described_class.search(query: query, page: 1).last.fetch_irasuto).to have_attributes(
      url: detail_uri.to_s, title: '太った少年のイラスト（肥満）'
    )
  end

  it 'returns an empty array beyond the last page' do
    expect(described_class.search(query: query, page: 2)).to eq([])
    expect(page_http).to have_received(:request_get).with(next_uri.request_uri).once
  end

  it 'returns an empty array without another request when the older link is malformed' do
    stub_search_page(search_uri, first_results, 'https://[bad]/search')

    expect(described_class.search(query: query, page: 1)).to eq([])
    expect(page_http).to have_received(:request_get).once
  end

  it 'propagates URI errors raised while fetching a valid older link' do
    allow(page_http).to receive(:request_get).with(next_uri.request_uri).and_raise(URI::InvalidURIError)

    expect { described_class.search(query: query, page: 1) }.to raise_error(URI::InvalidURIError)
  end

  it 'yields the current page and stops enumeration when the older link is malformed' do
    stub_search_page(search_uri, first_results, 'https://[bad]/search')
    expected_urls = first_results.map { |path| URI.join(search_url, path).to_s }

    expect(described_class.each_search_result(query: query).map(&:show_url)).to eq(expected_urls)
    expect(page_http).to have_received(:request_get).once
  end

  it 'fetches nothing until enumeration starts and stops at a page boundary' do
    results = described_class.each_search_result(query: query)

    expect(results).to be_an(Enumerator)
    expect(page_http).not_to have_received(:request_get)
    expect(results.take(7)).to all(be_a(Irasutoya::IrasutoLink))
    expect(page_http).to have_received(:request_get).with(search_uri.request_uri).once
    expect(page_http).not_to have_received(:request_get).with(next_uri.request_uri)
  end

  it 'enumerates results in order through the last page with one request per page' do
    expected_urls = (first_results + next_results).map { |path| URI.join(search_url, path).to_s }
    links = described_class.each_search_result(query: query).to_a

    expect(links.map(&:show_url)).to eq(expected_urls)
    expect(links.map(&:thumbnail_url)).to eq([thumbnail_url] * expected_urls.size)
    expect(page_http).to have_received(:request_get).with(search_uri.request_uri).once
    expect(page_http).to have_received(:request_get).with(next_uri.request_uri).once
  end

  it 'stops enumeration when older links form a cycle' do
    stub_search_page(next_uri, next_results, search_url)
    expected_urls = (first_results + next_results).map { |path| URI.join(search_url, path).to_s }

    results = described_class.each_search_result(query: query).take(expected_urls.size + 1)

    expect(results.map(&:show_url)).to eq(expected_urls)
    expect(page_http).to have_received(:request_get).with(search_uri.request_uri).once
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

  it 'does not refetch the redirected page when its relative older link points to itself' do
    redirected_uri = URI.join(search_url, '/archive/results?q=cat')
    redirect = Net::HTTPFound.new('1.1', '302', 'Found')
    redirect['Location'] = redirected_uri.to_s
    redirect['Content-Length'] = '0'
    allow(redirect).to receive(:read_body)
    allow(page_http).to receive(:request_get).with(search_uri.request_uri).and_yield(redirect).and_return(redirect)
    stub_search_page(redirected_uri, first_results, 'results?q=cat')

    expect(described_class.search(query: query, page: 1)).to eq([])
    expect(page_http).to have_received(:request_get).with(search_uri.request_uri).once
    expect(page_http).to have_received(:request_get).with(redirected_uri.request_uri).once
  end

  context 'when the older page redirects to the first page' do
    before do
      redirect = Net::HTTPFound.new('1.1', '302', 'Found')
      redirect['Location'] = search_uri.request_uri
      redirect['Content-Length'] = '0'
      allow(redirect).to receive(:read_body)
      allow(page_http).to receive(:request_get).with(next_uri.request_uri).and_yield(redirect).and_return(redirect)
    end

    it 'returns the redirected results for the requested page' do
      expected_urls = first_results.map { |path| URI.join(search_url, path).to_s }

      expect(described_class.search(query: query, page: 1).map(&:show_url)).to eq(expected_urls)
    end

    it 'stops enumeration before yielding the redirected results again' do
      expected_urls = first_results.map { |path| URI.join(search_url, path).to_s }
      results = described_class.each_search_result(query: query).take(expected_urls.size + 1)

      expect(results.map(&:show_url)).to eq(expected_urls)
      expect(page_http).to have_received(:request_get).with(next_uri.request_uri).once
    end
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

    it 'resolves pagination and detail links from the effective URLs during enumeration' do
      results = described_class.each_search_result(query: query).drop(first_results.size)

      expect(results.map(&:show_url)).to eq(%w[
        https://www.irasutoya.com/archive/cats/cat-8.html https://www.irasutoya.com/2018/09/cat-9.html
      ])
      expect(page_http).to have_received(:request_get).with(first_page_uri.request_uri).once
      expect(page_http).to have_received(:request_get).with(next_uri.request_uri).once
    end
  end

  def stub_search_page(uri, paths, older_href = nil)
    results = paths.map do |path|
      <<~HTML
        <div class="box">
          <div class="boxim">
            <a href="#{path}"><script>document.write(bp_thumbnail_resize("#{thumbnail_url}", 72));</script></a>
          </div>
          <a href="#{path}">Cat</a>
        </div>
      HTML
    end
    pager = %(<a class="blog-pager-older-link" href="#{CGI.escapeHTML(older_href)}">Next</a>) if older_href
    stub_html(page_http, "<html><body>#{results.join}#{pager}</body></html>", path: uri.request_uri)
  end
end

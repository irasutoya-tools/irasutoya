# frozen_string_literal: true

RSpec.describe Irasutoya::Category do
  let(:http) { stub_page_http }
  let(:first_path) { '/search/label/%E7%8C%AB' }
  let(:next_path) { "#{first_path}?updated-max=2018-09-01T12:00:00%2B09:00&max-results=20" }
  let(:category) { described_class.new(title: '猫', list_url: "https://www.irasutoya.com#{first_path}") }

  before do
    stub_html(http, File.read('spec/files/category_first_page.html'), path: first_path)
    stub_html(http, File.read('spec/files/category_last_page.html'), path: next_path)
  end

  it 'yields links across category pages to a block and stops at the last page' do
    links = []
    category.each_irasuto_link { |link| links << link }

    expect(links.map(&:title)).to eq(['Sleeping cat', 'Walking cat'])
    expect(links.last.show_url).to eq('https://www.irasutoya.com/2018/08/cat-2.html')
    expect(http).to have_received(:request_get).with(first_path).once
    expect(http).to have_received(:request_get).with(next_path).once
  end

  it 'does not fetch the next page until the enumerator advances to it' do
    results = category.each_irasuto_link
    expect(http).not_to have_received(:request_get)

    expect(results.next.title).to eq('Sleeping cat')
    expect(http).not_to have_received(:request_get).with(next_path)
    expect(results.next.title).to eq('Walking cat')
    expect { results.next }.to raise_error(StopIteration)
    expect(http).to have_received(:request_get).with(first_path).once
    expect(http).to have_received(:request_get).with(next_path).once
  end

  it 'keeps the array-returning method on the first page' do
    expect(category.fetch_irasuto_links.map(&:title)).to eq(['Sleeping cat'])
    expect(http).not_to have_received(:request_get).with(next_path)
  end

  it 'yields the current category results and stops at an off-origin older link' do
    html = File.read('spec/files/category_first_page.html')
    html = html.sub(/href="\?[^"]+"/, 'href="//example.com/search/label/cat"')
    stub_html(http, html, path: first_path)

    expect(category.each_irasuto_link.map(&:title)).to eq(['Sleeping cat'])
    expect(http).to have_received(:request_get).with(first_path).once
    expect(http).to have_received(:request_get).once
  end

  it 'stops after one fetch when the older-results link points to the current listing over HTTP' do
    html = File.read('spec/files/category_first_page.html')
    html = html.sub(/href="\?[^"]+"/, %(href="http://www.irasutoya.com#{first_path}"))
    stub_html(http, html, path: first_path)

    expect(category.each_irasuto_link.map(&:title)).to eq(['Sleeping cat'])
    expect(http).to have_received(:request_get).with(first_path).once
    expect(http).to have_received(:request_get).once
  end

  it 'advances to the next page when the older-results link uses HTTP with a distinct query' do
    distinct_path = "#{first_path}?page=2"
    html = File.read('spec/files/category_first_page.html')
    html = html.sub(/href="\?[^"]+"/, %(href="http://www.irasutoya.com#{distinct_path}"))
    stub_html(http, html, path: first_path)
    stub_html(http, File.read('spec/files/category_last_page.html'), path: distinct_path)

    expect(category.each_irasuto_link.map(&:title)).to eq(['Sleeping cat', 'Walking cat'])
    expect(http).to have_received(:request_get).with(first_path).once
    expect(http).to have_received(:request_get).with(distinct_path).once
  end

  it 'stops traversal when an older-results redirect lands on an already visited listing' do
    redirect_path = "#{first_path}/more"
    html = File.read('spec/files/category_first_page.html')
    html = html.sub(/href="\?[^"]+"/, %(href="#{redirect_path}"))
    stub_html(http, html, path: first_path)

    response = Net::HTTPFound.new('1.1', '302', 'Found')
    response['Location'] = "http://www.irasutoya.com#{first_path}"
    response['Content-Length'] = '0'
    allow(response).to receive(:read_body)
    allow(http).to receive(:request_get).with(redirect_path).and_yield(response).and_return(response)

    expect(category.each_irasuto_link.map(&:title)).to eq(['Sleeping cat'])
    expect(http).to have_received(:request_get).with(redirect_path).once
  end

  context 'when the list URL has an empty path' do
    let(:category) { described_class.new(title: '猫', list_url: 'https://www.irasutoya.com') }
    let(:root_page) do
      <<~HTML
        <div class="box">
          <a href="/2018/09/cat-1.html">Image</a><a href="/2018/09/cat-1.html">Sleeping cat</a>
        </div>
        <a class="blog-pager-older-link" href="/">Next</a>
      HTML
    end

    it 'fetches and yields the root listing once when its older-results link points to /' do
      stub_html(http, root_page, path: '/')

      expect(category.each_irasuto_link.map(&:title)).to eq(['Sleeping cat'])
      expect(http).to have_received(:request_get).with('/').once
    end

    it 'fetches and yields the listing once when it is reached through a redirect' do
      redirected_category = described_class.new(title: '猫', list_url: 'https://www.irasutoya.com/old-path')
      response = Net::HTTPFound.new('1.1', '302', 'Found')
      response['Location'] = 'https://www.irasutoya.com'
      response['Content-Length'] = '0'
      allow(response).to receive(:read_body)
      allow(http).to receive(:request_get).with('/old-path').and_yield(response).and_return(response)
      stub_html(http, root_page, path: '/')

      expect(redirected_category.each_irasuto_link.map(&:title)).to eq(['Sleeping cat'])
      expect(http).to have_received(:request_get).with('/old-path').once
      expect(http).to have_received(:request_get).with('/').once
    end

    it 'advances to the next page when the older-results link to the root carries a distinct query' do
      distinct_path = '/?start=10'
      html = root_page.sub('href="/"', %(href="#{distinct_path}"))
      stub_html(http, html, path: '/')
      stub_html(http, File.read('spec/files/category_last_page.html'), path: distinct_path)

      expect(category.each_irasuto_link.map(&:title)).to eq(['Sleeping cat', 'Walking cat'])
      expect(http).to have_received(:request_get).with('/').once
      expect(http).to have_received(:request_get).with(distinct_path).once
    end
  end
end

# frozen_string_literal: true

RSpec.describe 'Numbered search pagination' do
  let(:http) { stub_page_http }
  let(:path) { '/search?q=cat' }

  it 'stops after one fetch when the older-results link points to the current page over HTTP' do
    html = '<a class="blog-pager-older-link" href="http://www.irasutoya.com/search?q=cat">Next</a>'
    stub_html(http, html, path: path)

    expect(Irasutoya::Irasuto.search(query: 'cat', page: 1)).to eq([])
    expect(http).to have_received(:request_get).with(path).once
    expect(http).to have_received(:request_get).once
  end

  it 'advances to the next page when the older-results link uses HTTP with a distinct query' do
    next_path = '/search?q=cat&start=7'
    html = '<a class="blog-pager-older-link" href="http://www.irasutoya.com/search?q=cat&start=7">Next</a>'
    stub_html(http, html, path: path)
    stub_html(http, '<html></html>', path: next_path)

    expect(Irasutoya::Irasuto.search(query: 'cat', page: 1)).to eq([])
    expect(http).to have_received(:request_get).with(path).once
    expect(http).to have_received(:request_get).with(next_path).once
  end
end

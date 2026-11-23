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
end

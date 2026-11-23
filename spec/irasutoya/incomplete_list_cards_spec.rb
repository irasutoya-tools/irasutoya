# frozen_string_literal: true

RSpec.describe 'Listings with incomplete result cards' do
  let(:expected) do
    [
      ['Kitten', 'https://www.irasutoya.com/2018/09/kitten.html', 'https://example.com/kitten.png'],
      ['Mouse', 'https://www.irasutoya.com/2018/09/mouse.html', 'https://example.com/mouse.png'],
      ['Bird', 'https://www.irasutoya.com/2018/09/bird.html', nil]
    ]
  end

  let(:category) { Irasutoya::Category.new(title: 'Animals', list_url: 'https://www.irasutoya.com/search/label/animals') }

  before { stub_page('list_with_incomplete_cards.html') }

  it 'returns valid search results in page order' do
    results = Irasutoya::Irasuto.search(query: 'animals')

    expect(results.map { |link| [link.title, link.show_url, link.thumbnail_url] }).to eq(expected)
  end

  it 'returns valid category results in page order' do
    results = category.fetch_irasuto_links

    expect(results.map { |link| [link.title, link.show_url, link.thumbnail_url] }).to eq(expected)
  end

  it 'enumerates only complete search cards in order with their thumbnails' do
    results = Irasutoya::Irasuto.each_search_result(query: 'animals')

    expect(results.map { |link| [link.title, link.show_url, link.thumbnail_url] }).to eq(expected)
  end

  it 'enumerates only complete category cards in order with their thumbnails' do
    results = category.each_irasuto_link

    expect(results.map { |link| [link.title, link.show_url, link.thumbnail_url] }).to eq(expected)
  end
end

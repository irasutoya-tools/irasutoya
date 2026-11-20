# frozen_string_literal: true

RSpec.describe 'Listings with incomplete result cards' do
  let(:expected) do
    [['Mouse', 'https://www.irasutoya.com/2018/09/mouse.html'], ['Bird', 'https://www.irasutoya.com/2018/09/bird.html']]
  end

  before { stub_page('list_with_incomplete_cards.html') }

  it 'returns valid search results in page order' do
    results = Irasutoya::Irasuto.search(query: 'animals')

    expect(results.map { |link| [link.title, link.show_url] }).to eq(expected)
  end

  it 'returns valid category results in page order' do
    category = Irasutoya::Category.new(title: 'Animals', list_url: 'https://www.irasutoya.com/search/label/animals')
    results = category.fetch_irasuto_links

    expect(results.map { |link| [link.title, link.show_url] }).to eq(expected)
  end
end

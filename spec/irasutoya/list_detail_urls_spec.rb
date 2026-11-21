# frozen_string_literal: true

RSpec.describe 'Listing detail URLs' do
  let(:document) do
    Nokogiri::HTML.parse(File.read('spec/files/list_with_detail_urls.html'),
                         'https://www.irasutoya.com/2018/09/index.html')
  end
  let(:expected_urls) do
    %w[http://www.irasutoya.com/2018/09/mouse.html https://www.irasutoya.com/2018/09/bird.html]
  end

  it 'returns only trusted search links resolved against the effective listing URL' do
    allow(Irasutoya::Irasuto).to receive(:fetch_page_and_parse).and_return(document)

    expect(Irasutoya::Irasuto.search(query: 'animals').map(&:show_url)).to eq(expected_urls)
  end

  it 'returns only trusted category links resolved against the effective listing URL' do
    category = Irasutoya::Category.new(title: 'Animals', list_url: 'https://www.irasutoya.com/search/label/animals')
    allow(category).to receive(:fetch_page_and_parse).and_return(document)

    expect(category.fetch_irasuto_links.map(&:show_url)).to eq(expected_urls)
  end
end

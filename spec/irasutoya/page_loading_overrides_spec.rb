# frozen_string_literal: true

RSpec.describe 'Page loading overrides' do
  let(:document) { Object.new }
  let(:detail_url) { 'https://example.com/illustration' }

  shared_examples 'list loading with receiver overrides' do
    it 'builds links from the receiver fetch and parser results' do
      allow(receiver).to receive(:fetch_page_and_parse).with(list_url).and_return(document)
      allow(receiver).to receive(:parse_list_page).with(document: document)
                                                  .and_return([{ title: 'Custom link', show_url: detail_url }])

      expect(links).to contain_exactly(
        an_instance_of(Irasutoya::IrasutoLink).and(have_attributes(title: 'Custom link', show_url: detail_url))
      )
    end
  end

  shared_examples 'detail loading with receiver overrides' do
    it 'builds an illustration from the receiver fetch and parser results' do
      image_urls = ['https://example.com/image.png']
      allow(receiver).to receive(:fetch_page_and_parse).with(detail_url).and_return(document)
      allow(receiver).to receive(:parse_show_page).with(document: document)
                                                  .and_return(title: 'Custom title', description: 'Custom description',
                                                              image_urls: image_urls)

      expect(illustration).to be_an_instance_of(Irasutoya::Irasuto)
        .and(have_attributes(url: detail_url, title: 'Custom title', description: 'Custom description',
                             image_urls: image_urls))
    end
  end

  describe 'search' do
    let(:receiver) { Class.new(Irasutoya::Irasuto) }
    let(:list_url) { 'https://www.irasutoya.com/search?q=cat' }
    let(:links) { receiver.search(query: 'cat') }

    include_examples 'list loading with receiver overrides'
  end

  describe 'category browsing' do
    let(:receiver) { Class.new(Irasutoya::Category).new(title: 'Cats', list_url: list_url) }
    let(:list_url) { 'https://example.com/categories/cats' }
    let(:links) { receiver.fetch_irasuto_links }

    include_examples 'list loading with receiver overrides'
  end

  describe 'random detail loading' do
    let(:receiver) { Class.new(Irasutoya::Irasuto) }
    let(:detail_url) { 'http://www.irasutoya.com/2014/03/blog-post_5924.html' }
    let(:illustration) { receiver.random }

    before do
      response = Net::HTTPOK.new('1.1', '200', 'OK')
      allow(response).to receive(:body).and_return(File.read('spec/files/posts_summary.jsonp'))
      allow(Net::HTTP).to receive(:get_response).and_return(response)
      allow(Random).to receive(:rand).with(22_312).and_return(0)
    end

    include_examples 'detail loading with receiver overrides'
  end

  describe 'link traversal' do
    let(:receiver) { Class.new(Irasutoya::IrasutoLink).new(title: 'Cat', show_url: detail_url) }
    let(:illustration) { receiver.fetch_irasuto }

    include_examples 'detail loading with receiver overrides'
  end
end

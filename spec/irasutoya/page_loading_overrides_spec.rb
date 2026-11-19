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
      expected_document = document
      receiver.define_singleton_method(:parse_show_page) do |document:|
        raise 'Unexpected document' unless document.equal?(expected_document)

        { title: 'Custom title', description: 'Custom description', image_urls: image_urls }
      end

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

    it 'uses the receiver fetch override for every search page and parses the requested page' do
      next_url = 'https://www.irasutoya.com/search?q=cat&start=7'
      first_page = Nokogiri::HTML.parse('<a class="blog-pager-older-link" href="?q=cat&start=7">Next</a>')
      allow(receiver).to receive(:fetch_page_and_parse).with(list_url).and_return(first_page)
      allow(receiver).to receive(:fetch_page_and_parse).with(next_url).and_return(document)
      expect(receiver).to receive(:parse_list_page).with(document: document)
                                                   .and_return([{ title: 'Custom link', show_url: detail_url }])

      expect(receiver.search(query: 'cat', page: 1).map(&:show_url)).to eq([detail_url])
    end
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
      feed_url = 'https://www.irasutoya.com/feeds/posts/summary?start-index=1&max-results=1&alt=json-in-script'
      allow(Irasutoya::ResponseFetcher).to receive(:get).with(feed_url, max_bytes: 1024 * 1024, follow_redirects: false)
                                                      .and_return([File.read('spec/files/posts_summary.jsonp'), nil])
      allow(Random).to receive(:rand).with(22_312).and_return(0)
    end

    include_examples 'detail loading with receiver overrides'
  end

  describe 'saved URL loading' do
    let(:receiver) { Class.new(Irasutoya::Irasuto) }
    let(:detail_url) { 'https://www.irasutoya.com/2014/03/blog-post_5924.html' }

    it 'passes the page URL to URL-aware parser overrides' do
      allow(receiver).to receive(:fetch_page_and_parse).with(detail_url).and_return(document)
      expected_document = document
      receiver.define_singleton_method(:parse_show_page) do |document:, url:|
        raise 'Unexpected document' unless document.equal?(expected_document)

        { title: 'Saved post', description: '', image_urls: [URI.join(url, 'image.png').to_s] }
      end

      expect(receiver.from_url(detail_url).image_url).to eq('https://www.irasutoya.com/2014/03/image.png')
    end

    it 'resolves relative images against the fetched document URL while retaining the requested URL' do
      final_url = 'https://www.irasutoya.com/2026/11/post.html'
      html = '<div class="post"><div class="title"><h2>Cat</h2></div><div class="entry"><img src="cat.png"></div></div>'
      redirected_document = Nokogiri::HTML.parse(html, final_url)
      allow(receiver).to receive(:fetch_page_and_parse).with(detail_url).and_return(redirected_document)

      expect(receiver.from_url(detail_url)).to have_attributes(
        url: detail_url, image_url: 'https://www.irasutoya.com/2026/11/cat.png'
      )
    end
  end

  describe 'link traversal' do
    let(:receiver) { Class.new(Irasutoya::IrasutoLink).new(title: 'Cat', show_url: detail_url) }
    let(:illustration) { receiver.fetch_irasuto }

    include_examples 'detail loading with receiver overrides'
  end
end

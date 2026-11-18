# frozen_string_literal: true

RSpec.describe Irasutoya::Irasuto do # rubocop:disable Metric/BlockLength
  describe '.from_url' do
    it 'reopens a saved post URL with its title, description, and image' do
      url = 'https://www.irasutoya.com/2014/03/blog-post_5924.html'
      http = stub_page('show.html')
      saved_url = described_class.from_url(url).url

      expect(described_class.from_url(saved_url)).to have_attributes(
        url: url,
        title: '太った少年のイラスト（肥満）',
        description: '標準体重よりも少し太った小学生～中学生くらいの少年（肥満児）のイラストです。',
        image_url: 'https://4.bp.blogspot.com/-7Pa9IazPoII/VGLMYk-SjpI/AAAAAAAAo_s/IryhUKoFJQ0/s400/himan03_youngman.png'
      )
      expect(http).to have_received(:get).with('/2014/03/blog-post_5924.html').twice
    end

    it 'rejects a search results page' do
      stub_page('list.html')

      expect { described_class.from_url('https://www.irasutoya.com/search?q=test') }
        .to raise_error(ArgumentError, 'URL does not point to an Irasutoya illustration post')
    end

    it 'rejects off-origin URLs and relative paths before opening a connection' do
      expect(Net::HTTP).not_to receive(:new)

      %w[https://example.com/2014/03/blog-post.html /2014/03/blog-post.html].each do |url|
        expect { described_class.from_url(url) }.to raise_error(ArgumentError, 'Untrusted Irasutoya page URL')
      end
    end
  end

  describe 'image accessors' do
    it 'keeps single-image results when the constructor array grows' do
      urls = ['first']
      illustration = described_class.new(url: 'page', title: 'Title', description: 'Description', image_urls: urls)
      urls << 'second'

      expect(illustration.image_urls).to eq(['first'])
      expect(illustration.image_url).to eq('first')
      expect(illustration.postthumb_image_url).to be_nil
      expect(illustration.has_multiple_images).to be(false)
    end

    it 'keeps multiple-image results when the returned array is cleared' do
      urls = %w[first second]
      illustration = described_class.new(url: 'page', title: 'Title', description: 'Description', image_urls: urls)
      illustration.image_urls.clear

      expect(illustration.image_urls).to eq(%w[first second])
      expect(illustration.image_url).to eq('first')
      expect(illustration.postthumb_image_url).to eq('first')
      expect(illustration.has_multiple_images).to be(true)
    end
  end

  describe '#random' do # rubocop:disable Metrics/BlockLength
    let(:feed_body) { File.read('spec/files/posts_summary.jsonp') }
    let(:feed_count) { 22_312 }
    let(:feed_response) do
      Net::HTTPOK.new('1.1', '200', 'OK').tap do |response|
        allow(response).to receive(:body).and_return(feed_body)
      end
    end
    let(:show_url) { 'http://www.irasutoya.com/2014/03/blog-post_5924.html' }
    let(:page_fixture) { 'show.html' }
    let(:page_http) { stub_page(page_fixture) }

    before do
      allow(Random).to receive(:rand).with(feed_count).and_return(0)
      allow(Net::HTTP).to receive(:get_response).with(feed_uri(1)).and_return(feed_response)
      page_http
    end

    def feed_uri(index)
      URI.parse("https://www.irasutoya.com/feeds/posts/summary?start-index=#{index}&max-results=1&alt=json-in-script")
    end

    it 'returns the first entry for a draw of zero without requesting index zero' do
      expect(Net::HTTP).to receive(:get_response).with(feed_uri(1)).once.and_return(feed_response)

      expect(described_class.random.url).to eq(show_url)
    end

    it 'requests the last reported index for the highest draw' do
      allow(Random).to receive(:rand).with(feed_count).and_return(feed_count - 1)
      expect(Net::HTTP).to receive(:get_response).with(feed_uri(feed_count)).and_return(feed_response)

      expect(described_class.random.url).to eq(show_url)
    end

    it 'raises an HTTP error before parsing a failed count response' do
      response = Net::HTTPBadRequest.new('1.1', '400', 'Bad Request')
      allow(Net::HTTP).to receive(:get_response).with(feed_uri(1)).and_return(response)
      expect(response).not_to receive(:body)

      expect { described_class.random }.to raise_error(Net::HTTPClientException, /400.*Bad Request/)
    end

    it 'raises an HTTP error before parsing a failed entry response' do
      response = Net::HTTPServiceUnavailable.new('1.1', '503', 'Service Unavailable')
      allow(Random).to receive(:rand).with(feed_count).and_return(feed_count - 1)
      allow(Net::HTTP).to receive(:get_response).with(feed_uri(feed_count)).and_return(response)
      expect(response).not_to receive(:body)

      expect { described_class.random }.to raise_error(Net::HTTPFatalError, /503.*Service Unavailable/)
    end

    it 'should return random irasuto' do
      expect(Irasutoya::Irasuto.random).to be_a(Irasutoya::Irasuto)
    end

    it 'should return random irasuto with url' do
      irasuto = Irasutoya::Irasuto.random

      expect(irasuto.url).to eq(show_url)
    end

    it 'fetches the legacy feed link over HTTPS' do
      Irasutoya::Irasuto.random

      expect(page_http.use_ssl?).to be(true)
      expect(page_http).to have_received(:get).with(URI.parse(show_url).request_uri).once
    end

    it 'rejects an off-origin feed link before opening a page connection' do
      allow(feed_response).to receive(:body).and_return(feed_body.gsub('www.irasutoya.com', 'example.com'))
      expect(Net::HTTP).not_to receive(:new)

      expect { Irasutoya::Irasuto.random }.to raise_error(ArgumentError, 'Untrusted Irasutoya page URL')
    end

    it 'should return random irasuto with title' do
      expect(Irasutoya::Irasuto.random.title).to eq('太った少年のイラスト（肥満）')
    end

    it 'should return random irasuto with description' do
      expect(Irasutoya::Irasuto.random.description).to eq('標準体重よりも少し太った小学生～中学生くらいの少年（肥満児）のイラストです。')
    end

    it 'should return random irasuto with image_url' do
      expect(Irasutoya::Irasuto.random.image_url).to eq('https://4.bp.blogspot.com/-7Pa9IazPoII/VGLMYk-SjpI/AAAAAAAAo_s/IryhUKoFJQ0/s400/himan03_youngman.png')
    end

    it 'should not have postthumb_image_url when image size is 1' do
      expect(Irasutoya::Irasuto.random.postthumb_image_url).to be_nil
    end

    it 'should not have images with size 1' do
      expect(Irasutoya::Irasuto.random.image_urls).to match [String]
    end

    context 'when there are multiple images on a page' do
      let(:page_fixture) { 'show_multiple_images.html' }

      it 'should return random irasuto with image_url' do
        expect(Irasutoya::Irasuto.random.image_url).to eq('https://1.bp.blogspot.com/-rchqpx0JGcU/XpKozq0JXAI/AAAAAAABYXA/BnJXB5WNKAcjeFC6_t2XPXwu7wUNAhL3gCNcBGAsYHQ/s195/thumbnail_jitakutaiki.jpg')
        expect(Irasutoya::Irasuto.random.postthumb_image_url).to eq('https://1.bp.blogspot.com/-rchqpx0JGcU/XpKozq0JXAI/AAAAAAABYXA/BnJXB5WNKAcjeFC6_t2XPXwu7wUNAhL3gCNcBGAsYHQ/s195/thumbnail_jitakutaiki.jpg')
      end

      it 'should have the same url in both image_url and postthumb_image_url' do
        random = Irasutoya::Irasuto.random
        expect(random.image_url).to eq random.postthumb_image_url
      end

      it 'should tell if it has multiple images' do
        expect(Irasutoya::Irasuto.random.has_multiple_images).to be_truthy
      end

      it 'should return array of urls' do
        expect(Irasutoya::Irasuto.random.image_urls).to eq %w[
          https://1.bp.blogspot.com/-rchqpx0JGcU/XpKozq0JXAI/AAAAAAABYXA/BnJXB5WNKAcjeFC6_t2XPXwu7wUNAhL3gCNcBGAsYHQ/s195/thumbnail_jitakutaiki.jpg
          https://1.bp.blogspot.com/-lpfwBjUUF14/XpKjSWe30_I/AAAAAAABYV4/I1XfuuYWbKYmlscvIobYDlj64WItEsoVgCNcBGAsYHQ/s300/jitakutaiki_uchidesugosou.png
          https://1.bp.blogspot.com/-SsQwk5T0cvw/XpKjR-QdEUI/AAAAAAABYVw/czkpHPV97JIuHJcUT-HBQMsmyd_6EAkRACNcBGAsYHQ/s300/jitakutaiki_ieniiyou.png
          https://1.bp.blogspot.com/-ZJ6jMVFzmKc/XpKjSFJkAkI/AAAAAAABYV0/vc9fK33XvGsmQQU6bg74TbNpcwdfcKDpACNcBGAsYHQ/s300/jitakutaiki_stayhome.png
        ]
      end
    end
  end

  describe '#search' do # rubocop:disable Metrics/BlockLength
    let(:query) { '検索' }
    let(:search_url) { 'https://www.irasutoya.com/search?q=%E6%A4%9C%E7%B4%A2' }
    let(:paginated_url) { "#{search_url}&max-results=20&start=40&by-date=false" }
    let(:html) { File.read('spec/files/list.html') }
    let(:results) { described_class.search(query: query) }

    let(:page_http) { stub_page('list.html') }

    before { page_http }

    include_examples 'ordered list results'

    it 'queries anchors once in each of the twenty result boxes' do
      document = Nokogiri::HTML.parse(html, nil, 'UTF-8')
      boxes = document.css('.box')
      expect(boxes.size).to eq(20)
      allow(Nokogiri::HTML).to receive(:parse).with(html, nil, 'utf-8').and_return(document)
      allow(document).to receive(:css).with('.box').and_return(boxes)
      boxes.each { |box| expect(box).to receive(:css).with('a').once.and_call_original }

      results
    end

    it 'loads links from the paginated search URL with their detail URLs' do
      link = Irasutoya::Irasuto.search(query: query, page: 2).first

      expect(page_http).to have_received(:get).with(URI.parse(paginated_url).request_uri).once
      expect(link).to be_a(Irasutoya::IrasutoLink)
      expect(link.show_url).to eq('https://www.irasutoya.com/2019/08/blog-post_81.html')
    end
  end
end

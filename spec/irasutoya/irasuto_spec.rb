# frozen_string_literal: true

RSpec.describe Irasutoya::Irasuto do # rubocop:disable Metrics/BlockLength
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
      expect(http).to have_received(:request_get).with('/2014/03/blog-post_5924.html').twice
    end

    it 'trims relative image sources and skips blank sources in document order' do
      stub_page('show_with_padded_image_sources.html')

      expect(described_class.from_url('https://www.irasutoya.com/2014/03/blog-post.html').image_urls).to eq(%w[
        https://www.irasutoya.com/2014/03/cat.png
        https://www.irasutoya.com/2014/03/second.png
      ])
    end

    it 'rejects a search results page' do
      stub_page('list.html')

      expect { described_class.from_url('https://www.irasutoya.com/search?q=test') }
        .to raise_error(ArgumentError, 'URL does not point to an Irasutoya illustration post')
    end

    it 'rejects a titled post with only missing or blank image sources' do
      stub_page('show_without_image_sources.html')

      expect { described_class.from_url('https://www.irasutoya.com/2014/03/blog-post.html') }
        .to raise_error(ArgumentError, 'URL does not point to an Irasutoya illustration post')
    end

    it 'rejects off-origin URLs and relative paths before opening a connection' do
      expect(Net::HTTP).not_to receive(:new)

      %w[https://example.com/2014/03/blog-post.html /2014/03/blog-post.html].each do |url|
        expect { described_class.from_url(url) }.to raise_error(ArgumentError, 'Untrusted Irasutoya page URL')
      end
    end

    it 'rejects malformed URLs before opening a connection' do
      expect(Net::HTTP).not_to receive(:new)

      ['/search?q=猫', 'https://www.irasutoya.com:bad/post.html'].each do |url|
        expect { described_class.from_url(url) }.to raise_error(ArgumentError, 'Invalid Irasutoya page URL')
      end
    end

    it 'preserves URI errors raised while fetching a valid URL' do
      http = stub_page_http
      allow(http).to receive(:request_get).and_raise(URI::InvalidURIError)

      expect { described_class.from_url('https://www.irasutoya.com/post.html') }.to raise_error(URI::InvalidURIError)
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
    let(:feed_response) { jsonp_response(feed_body) }

    def jsonp_response(body)
      Net::HTTPOK.new('1.1', '200', 'OK').tap do |response|
        allow(response).to receive(:read_body).and_yield(body)
      end
    end

    let(:feed_http) { instance_double(Net::HTTP) }
    let(:show_url) { 'http://www.irasutoya.com/2014/03/blog-post_5924.html' }
    let(:page_fixture) { 'show.html' }
    let(:page_http) { stub_page(page_fixture) }

    before do
      allow(Random).to receive(:rand).with(feed_count).and_return(0)
      allow(feed_http).to receive(:finish)
      allow(Net::HTTP).to receive(:start)
                         .with('www.irasutoya.com', 443, use_ssl: true, ignore_eof: false).and_yield(feed_http)
      allow(feed_http).to receive(:request_get).with(feed_path(1)).and_yield(feed_response).and_return(feed_response)
      page_http
    end

    def feed_path(index)
      "/feeds/posts/summary?start-index=#{index}&max-results=1&alt=json-in-script"
    end

    it 'returns the first entry for a draw of zero without requesting index zero' do
      expect(feed_http).to receive(:request_get).with(feed_path(1)).once.and_yield(feed_response).and_return(feed_response)

      expect(described_class.random.url).to eq(show_url)
    end

    it 'requests the last reported index for the highest draw' do
      allow(Random).to receive(:rand).with(feed_count).and_return(feed_count - 1)
      expect(feed_http).to receive(:request_get).with(feed_path(feed_count)).and_yield(feed_response).and_return(feed_response)

      expect(described_class.random.url).to eq(show_url)
    end

    it 'makes one feed request and one detail request with a fresh count' do
      allow(Random).to receive(:rand).with(feed_count).and_return(0, 1)
      expect(feed_http).to receive(:request_get).with(feed_path(1)).once
                                   .and_yield(feed_response).and_return(feed_response)
      expect(feed_http).to receive(:request_get).with(feed_path(2)).once
                                   .and_yield(feed_response).and_return(feed_response)

      2.times { expect(described_class.random.url).to eq(show_url) }

      expect(page_http).to have_received(:request_get).with(URI.parse(show_url).request_uri).twice
    end

    it 'uses a refreshed count after the cache expires' do
      allow(described_class).to receive(:feed_count_time).and_return(100.0)
      described_class.random

      allow(described_class).to receive(:feed_count_time).and_return(400.0)
      updated_response = jsonp_response(feed_body.sub(feed_count.to_s, '2'))
      expect(feed_http).to receive(:request_get).with(feed_path(1)).ordered
                                   .and_yield(updated_response).and_return(updated_response)
      expect(Random).to receive(:rand).with(2).ordered.and_return(1)
      expect(feed_http).to receive(:request_get).with(feed_path(2)).ordered
                                   .and_yield(updated_response).and_return(updated_response)

      expect(described_class.random.url).to eq(show_url)
    end

    it 'refreshes and resamples when the selected entry is missing after the feed shrinks' do
      allow(Random).to receive(:rand).with(feed_count).and_return(0, feed_count - 1)
      described_class.random

      missing_entry = jsonp_response('callback({"feed":{"openSearch$totalResults":{"$t":"2"}}});')
      updated_response = jsonp_response(feed_body.sub(feed_count.to_s, '2'))
      expect(feed_http).to receive(:request_get).with(feed_path(feed_count)).ordered
                                   .and_yield(missing_entry).and_return(missing_entry)
      expect(feed_http).to receive(:request_get).with(feed_path(1)).ordered
                                   .and_yield(updated_response).and_return(updated_response)
      expect(Random).to receive(:rand).with(2).ordered.twice.and_return(0, 1)
      expect(feed_http).to receive(:request_get).with(feed_path(2)).ordered
                                   .and_yield(updated_response).and_return(updated_response)

      2.times { expect(described_class.random.url).to eq(show_url) }
    end

    it 'raises an HTTP error before parsing a failed count response' do
      response = Net::HTTPBadRequest.new('1.1', '400', 'Bad Request')
      allow(feed_http).to receive(:request_get).with(feed_path(1)).and_yield(response)
      expect(response).not_to receive(:read_body)

      expect { described_class.random }.to raise_error(Net::HTTPClientException, /400.*Bad Request/)
    end

    it 'raises an HTTP error before parsing a failed entry response' do
      response = Net::HTTPServiceUnavailable.new('1.1', '503', 'Service Unavailable')
      allow(Random).to receive(:rand).with(feed_count).and_return(feed_count - 1)
      allow(feed_http).to receive(:request_get).with(feed_path(feed_count)).and_yield(response)
      expect(response).not_to receive(:read_body)

      expect { described_class.random }.to raise_error(Net::HTTPFatalError, /503.*Service Unavailable/)
    end

    it 'raises a type error when the feed has no JSON payload' do
      allow(feed_response).to receive(:read_body).and_yield('callback();')

      expect { described_class.random }.to raise_error(TypeError, 'no implicit conversion of nil into String')
    end

    it 'reports an empty feed without choosing an index or fetching a detail page' do
      allow(feed_response).to receive(:read_body).and_yield('callback({"feed":{"openSearch$totalResults":{"$t":"0"}}});')
      expect(Random).not_to receive(:rand).with(0)
      expect(page_http).not_to receive(:request_get)

      expect { described_class.random }.to raise_error(RuntimeError, 'Illustration feed has no entries')
    end

    it 'rejects an oversized count feed before choosing a random index' do
      stub_const('Irasutoya::Irasuto::MAX_FEED_BYTES', feed_body.bytesize - 1)
      expect(Random).not_to receive(:rand)

      expect { described_class.random }.to raise_error(Irasutoya::ResponseTooLargeError)
    end

    it 'rejects an oversized entry feed before fetching its detail page' do
      stub_const('Irasutoya::Irasuto::MAX_FEED_BYTES', feed_body.bytesize)
      oversized = Net::HTTPOK.new('1.1', '200', 'OK')
      allow(oversized).to receive(:read_body).and_yield(feed_body).and_yield(' ')
      allow(Random).to receive(:rand).with(feed_count).and_return(feed_count - 1)
      allow(feed_http).to receive(:request_get).with(feed_path(feed_count)).and_yield(oversized)
      expect(page_http).not_to receive(:request_get)

      expect { described_class.random }.to raise_error(Irasutoya::ResponseTooLargeError)
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
      expect(page_http).to have_received(:request_get).with(URI.parse(show_url).request_uri).once
    end

    it 'rejects an off-origin feed link before opening a page connection' do
      allow(feed_response).to receive(:read_body).and_yield(feed_body.gsub('www.irasutoya.com', 'example.com'))
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
    let(:results) { described_class.search(query: query) }

    let(:page_http) { stub_page('list.html') }

    before { page_http }

    include_examples 'ordered list results'

    it 'queries anchors once in each of the twenty result boxes' do
      allow(Nokogiri::HTML).to receive(:parse).and_wrap_original do |parse, *args|
        document = parse.call(*args)
        boxes = document.css('.box')
        expect(boxes.size).to eq(20)
        allow(document).to receive(:css).with('.box').and_return(boxes)
        boxes.each { |box| expect(box).to receive(:css).with('a').once.and_call_original }
        document
      end

      results
    end

    it 'loads links from the initial search URL with their detail URLs' do
      link = results.first

      expect(page_http).to have_received(:request_get).with(URI.parse(search_url).request_uri).once
      expect(link).to be_a(Irasutoya::IrasutoLink)
      expect(link.show_url).to eq('https://www.irasutoya.com/2019/08/blog-post_81.html')
    end
  end
end

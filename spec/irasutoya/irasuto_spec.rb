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
        image_url: 'https://4.bp.blogspot.com/-7Pa9IazPoII/VGLMYk-SjpI/AAAAAAAAo_s/IryhUKoFJQ0/s400/himan03_youngman.png',
        published_on: Date.new(2014, 12, 9)
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

    context 'with a Shift_JIS detail page' do
      let(:url) { 'https://www.irasutoya.com/2014/03/blog-post.html' }
      let(:title) { '猫のイラスト' }
      let(:html) do
        <<~HTML.encode(Encoding::Shift_JIS).b
          <html>
            <head><meta http-equiv="Content-Type" content="text/html; charset=#{meta_charset}"></head>
            <body>
              <div class="post">
                <div class="title"><h2>#{title}</h2></div>
                <div class="entry"><img src="cat.png"></div>
              </div>
            </body>
          </html>
        HTML
      end

      context 'when the HTTP header omits the charset' do
        let(:meta_charset) { 'Shift_JIS' }

        it 'decodes the title using the HTML charset' do
          stub_html(stub_page_http, html, content_type: 'text/html')

          expect(described_class.from_url(url).title).to eq(title)
        end
      end

      context 'when the HTTP charset conflicts with the HTML charset' do
        let(:meta_charset) { 'UTF-8' }

        it 'decodes the title using the HTTP charset' do
          stub_html(stub_page_http, html, content_type: 'text/html; Charset="Shift_JIS"')

          expect(described_class.from_url(url).title).to eq(title)
        end
      end
    end

    it 'skips a leading one-pixel Blogger placeholder and keeps illustrations in order' do
      stub_page('show_with_one_pixel_placeholder.html')
      image_urls = %w[
        https://blogger.googleusercontent.com/img/b/steam/s150/mark_manpu01_yuge.png
        https://blogger.googleusercontent.com/img/b/laughter/s150/mark_manpu02_warai.png
      ]

      expect(described_class.from_url('https://www.irasutoya.com/2015/06/blog-post_275.html')).to have_attributes(
        image_urls: image_urls,
        image_url: image_urls.first,
        postthumb_image_url: image_urls.first
      )
    end

    it 'rejects a search results page' do
      stub_page('list.html')

      expect { described_class.from_url('https://www.irasutoya.com/search?q=test') }
        .to raise_error(ArgumentError, 'URL does not point to an Irasutoya illustration post')
    end

    it 'uses only the selected post for illustration details' do
      stub_page('show_with_unrelated_entry.html')

      expect(described_class.from_url('https://www.irasutoya.com/2014/03/blog-post.html')).to have_attributes(
        title: 'Illustration title',
        description: 'Illustration caption',
        image_urls: ['https://www.irasutoya.com/2014/03/art.png'],
        categories: [],
        has_multiple_images: false,
        published_on: nil
      )
    end

    it 'rejects a titled post with only missing or blank image sources even when another entry has an image' do
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

    {
      'missing' => nil,
      'empty' => '',
      'whitespace-only' => " \t ",
      'malformed' => '/invalid path'
    }.each do |condition, location|
      it "reports an HTTP error when the redirect Location is #{condition}" do
        http = stub_page_http
        response = Net::HTTPFound.new('1.1', '302', 'Found')
        response['Location'] = location
        allow(http).to receive(:request_get).with('/post.html').and_yield(response).and_return(response)

        expect { described_class.from_url('https://www.irasutoya.com/post.html') }
          .to raise_error(OpenURI::HTTPError, '302 Found (Invalid Location URI)')
        expect(http).to have_received(:request_get).once
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

  describe '#published_on' do
    it 'defaults to nil when the constructor omits it' do
      illustration = described_class.new(url: 'page', title: 'Title', description: 'Description',
                                         image_urls: ['first'])

      expect(illustration.published_on).to be_nil
    end

    it 'returns the date passed to the constructor' do
      illustration = described_class.new(url: 'page', title: 'Title', description: 'Description',
                                         image_urls: ['first'], published_on: Date.new(2026, 11, 26))

      expect(illustration.published_on).to eq(Date.new(2026, 11, 26))
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
    let(:show_url) { 'http://www.irasutoya.com/2014/03/blog-post_5924.html' }
    let(:page_fixture) { 'show.html' }
    let(:page_http) { stub_page(page_fixture) }

    before do
      allow(Random).to receive(:rand).with(feed_count).and_return(0)
      allow(page_http).to receive(:request_get).with(feed_path(1)).and_yield(feed_response).and_return(feed_response)
    end

    def feed_path(index)
      "/feeds/posts/summary?start-index=#{index}&max-results=1&alt=json-in-script"
    end

    it 'returns the first entry for a draw of zero without requesting index zero' do
      expect(page_http).to receive(:request_get).with(feed_path(1)).once
                                                .and_yield(feed_response).and_return(feed_response)

      expect(described_class.random.url).to eq(show_url)
    end

    it 'requests the last reported index for the highest draw' do
      allow(Random).to receive(:rand).with(feed_count).and_return(feed_count - 1)
      expect(page_http).to receive(:request_get).with(feed_path(feed_count))
                                                .and_yield(feed_response).and_return(feed_response)

      expect(described_class.random.url).to eq(show_url)
    end

    context 'with a multiline JSONP feed' do
      let(:feed_count) { 1 }
      let(:feed_body) do
        <<~JSONP
          gdata.io.handleScriptLoaded({
            "feed": {
              "openSearch$totalResults": { "$t": "1" },
              "entry": [{ "link": [{ "rel": "alternate", "href": "#{show_url}" }] }]
            }
          });
        JSONP
      end

      it 'returns an illustration from the feed' do
        expect(described_class.random).to have_attributes(
          url: show_url,
          title: '太った少年のイラスト（肥満）'
        )
      end
    end

    it 'makes one feed request and one detail request with a fresh count' do
      allow(Random).to receive(:rand).with(feed_count).and_return(0, 1)
      expect(page_http).to receive(:request_get).with(feed_path(1)).once
                                                .and_yield(feed_response).and_return(feed_response)
      expect(page_http).to receive(:request_get).with(feed_path(2)).once
                                                .and_yield(feed_response).and_return(feed_response)

      expect(page_http).to receive(:request_get).with(URI.parse(show_url).request_uri).twice

      2.times { expect(described_class.random.url).to eq(show_url) }
    end

    it 'uses a refreshed count after the cache expires' do
      allow(described_class::FEED_COUNT_CACHE).to receive(:clock_time).and_return(100.0)
      described_class.random

      allow(described_class::FEED_COUNT_CACHE).to receive(:clock_time).and_return(400.0)
      updated_response = jsonp_response(feed_body.sub(feed_count.to_s, '2'))
      expect(page_http).to receive(:request_get).with(feed_path(1)).ordered
                                                .and_yield(updated_response).and_return(updated_response)
      expect(Random).to receive(:rand).with(2).ordered.and_return(1)
      expect(page_http).to receive(:request_get).with(feed_path(2)).ordered
                                                .and_yield(updated_response).and_return(updated_response)

      expect(described_class.random.url).to eq(show_url)
    end

    it 'refreshes and resamples when the selected entry is missing after the feed shrinks' do
      allow(Random).to receive(:rand).with(feed_count).and_return(0, feed_count - 1)
      described_class.random

      missing_entry = jsonp_response('callback({"feed":{"openSearch$totalResults":{"$t":"2"}}});')
      updated_response = jsonp_response(feed_body.sub(feed_count.to_s, '2'))
      expect(page_http).to receive(:request_get).with(feed_path(feed_count)).ordered
                                                .and_yield(missing_entry).and_return(missing_entry)
      expect(page_http).to receive(:request_get).with(feed_path(1)).ordered
                                                .and_yield(updated_response).and_return(updated_response)
      expect(Random).to receive(:rand).with(2).ordered.twice.and_return(0, 1)
      expect(page_http).to receive(:request_get).with(feed_path(2)).ordered
                                                .and_yield(updated_response).and_return(updated_response)

      2.times { expect(described_class.random.url).to eq(show_url) }
    end

    context 'when the selected feed entry has no usable alternate URL' do
      let(:feed_count) { 1 }
      let(:feed_body) do
        feed = {
          'openSearch$totalResults' => { '$t' => '1' },
          'entry' => [{ 'link' => [{ 'rel' => 'self', 'href' => show_url }] }]
        }
        "callback(#{JSON.generate('feed' => feed)});"
      end

      it 'refreshes once and loads the detail page from the refreshed entry' do
        refreshed_response = jsonp_response(feed_body.sub('"self"', '"alternate"'))
        expect(page_http).to receive(:request_get).with(feed_path(1)).ordered.and_yield(feed_response)
        expect(page_http).to receive(:request_get).with(feed_path(1)).ordered.and_yield(refreshed_response)
        expect(page_http).to receive(:request_get).with(URI.parse(show_url).request_uri).ordered

        expect(described_class.random.url).to eq(show_url)
      end

      it 'reports the feed error after two selections without an alternate link' do
        expect(page_http).to receive(:request_get).with(feed_path(1)).twice.and_yield(feed_response)
        expect(page_http).not_to receive(:request_get).with(URI.parse(show_url).request_uri)

        expect { described_class.random }.to raise_error(RuntimeError, 'Illustration feed has no usable post URL')
      end

      it 'reports the feed error when the refreshed alternate URL is invalid' do
        refreshed_response = jsonp_response(feed_body.sub('"self"', '"alternate"').sub(show_url, '/relative.html'))
        expect(page_http).to receive(:request_get).with(feed_path(1)).ordered.and_yield(feed_response)
        expect(page_http).to receive(:request_get).with(feed_path(1)).ordered.and_yield(refreshed_response)

        expect { described_class.random }.to raise_error(RuntimeError, 'Illustration feed has no usable post URL')
      end
    end

    it 'raises an HTTP error before parsing a failed count response' do
      response = Net::HTTPBadRequest.new('1.1', '400', 'Bad Request')
      allow(page_http).to receive(:request_get).with(feed_path(1)).and_yield(response)
      expect(response).not_to receive(:read_body)

      expect { described_class.random }.to raise_error(Net::HTTPClientException, /400.*Bad Request/)
    end

    it 'raises an HTTP error before parsing a failed entry response' do
      response = Net::HTTPServiceUnavailable.new('1.1', '503', 'Service Unavailable')
      allow(Random).to receive(:rand).with(feed_count).and_return(feed_count - 1)
      allow(page_http).to receive(:request_get).with(feed_path(feed_count)).and_yield(response)
      expect(response).not_to receive(:read_body)

      expect { described_class.random }.to raise_error(Net::HTTPFatalError, /503.*Service Unavailable/)
    end

    it 'rejects feed redirects without requesting their target' do
      response = Net::HTTPFound.new('1.1', '302', 'Found')
      response['Location'] = show_url
      allow(page_http).to receive(:request_get).with(feed_path(1)).and_yield(response)
      expect(page_http).not_to receive(:request_get).with(URI.parse(show_url).request_uri)

      expect { described_class.random }.to raise_error(Net::HTTPRetriableError, /302.*Found/)
    end

    it 'raises a type error when the feed has no JSON payload' do
      allow(feed_response).to receive(:read_body).and_yield('callback();')

      expect { described_class.random }.to raise_error(TypeError, 'no implicit conversion of nil into String')
    end

    it 'rejects a non-integer feed count and retries the count on the next lookup' do
      invalid_response = jsonp_response('callback({"feed":{"openSearch$totalResults":{"$t":"12.5"}}});')
      expect(page_http).to receive(:request_get).with(feed_path(1)).ordered.and_yield(invalid_response)
      expect(page_http).to receive(:request_get).with(feed_path(1)).ordered.and_yield(feed_response)
      expect(Random).to receive(:rand).with(feed_count).once.and_return(0)
      expect(page_http).to receive(:request_get).with(URI.parse(show_url).request_uri).once.ordered

      expect { described_class.random }.to raise_error(ArgumentError, /invalid value for Integer.*12\.5/)
      expect(described_class.random.url).to eq(show_url)
    end

    it 'reports an empty feed without choosing an index or fetching a detail page' do
      empty_feed = 'callback({"feed":{"openSearch$totalResults":{"$t":"0"}}});'
      allow(feed_response).to receive(:read_body).and_yield(empty_feed)
      expect(Random).not_to receive(:rand).with(0)
      expect(page_http).not_to receive(:request_get).with(URI.parse(show_url).request_uri)

      expect { described_class.random }.to raise_error(RuntimeError, 'Illustration feed has no entries')
    end

    it 'fetches the count again on the next lookup after an empty feed' do
      empty_response = jsonp_response('callback({"feed":{"openSearch$totalResults":{"$t":"0"}}});')
      recovered_response = jsonp_response(feed_body.sub(feed_count.to_s, '1'))
      expect(page_http).to receive(:request_get).with(feed_path(1)).ordered
                                                .and_yield(empty_response).and_return(empty_response)
      expect(page_http).to receive(:request_get).with(feed_path(1)).ordered
                                                .and_yield(recovered_response).and_return(recovered_response)
      expect(Random).to receive(:rand).with(1).ordered.and_return(0)

      expect { described_class.random }.to raise_error(RuntimeError, 'Illustration feed has no entries')
      expect(described_class.random.url).to eq(show_url)
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
      allow(page_http).to receive(:request_get).with(feed_path(feed_count)).and_yield(oversized)
      expect(page_http).not_to receive(:request_get).with(URI.parse(show_url).request_uri)

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

    context 'when the selected post fails to load' do
      let(:missing_path) { '/deleted.html' }
      let(:feed_count) { 1 }
      let(:feed_body) { post_feed("https://www.irasutoya.com#{missing_path}") }
      let(:refreshed_response) { jsonp_response(post_feed(show_url)) }

      before do
        allow(page_http).to receive(:request_get).with(feed_path(1)).and_raise('Unexpected feed request')
        expect(page_http).to receive(:request_get).with(feed_path(1)).once.ordered.and_yield(feed_response)
      end

      shared_examples 'a missing post' do |response_class, status, message|
        before { expect_detail_error(missing_path, response_class, status, message) }

        it 'loads the post from the refreshed feed' do
          expect_feed_refresh
          expect(page_http).to receive(:request_get).with(URI.parse(show_url).request_uri).once.ordered

          expect(described_class.random.url).to eq(show_url)
        end
      end

      it_behaves_like 'a missing post', Net::HTTPNotFound, '404', 'Not Found'
      it_behaves_like 'a missing post', Net::HTTPGone, '410', 'Gone'

      it 'propagates the second missing response after one refresh' do
        expect_detail_error(missing_path, Net::HTTPNotFound, '404', 'Not Found')
        expect_feed_refresh
        expect_detail_error(URI.parse(show_url).request_uri, Net::HTTPGone, '410', 'Gone')

        expect { described_class.random }.to raise_error(OpenURI::HTTPError, '410 Gone')
      end

      it 'propagates other detail failures without refreshing the feed' do
        expect_detail_error(missing_path, Net::HTTPServiceUnavailable, '503', 'Service Unavailable')

        expect { described_class.random }.to raise_error(OpenURI::HTTPError, '503 Service Unavailable')
      end

      def expect_feed_refresh
        expect(page_http).to receive(:request_get).with(feed_path(1)).once.ordered.and_yield(refreshed_response)
      end

      def post_feed(url)
        feed = {
          'openSearch$totalResults' => { '$t' => feed_count.to_s },
          'entry' => [{ 'link' => [{ 'rel' => 'alternate', 'href' => url }] }]
        }
        "callback(#{JSON.generate('feed' => feed)});"
      end

      def expect_detail_error(path, response_class, status, message)
        response = response_class.new('1.1', status, message)
        allow(response).to receive(:body).and_return('')
        allow(response).to receive(:read_body).and_yield('')
        expect(page_http).to receive(:request_get).with(path).once.ordered.and_yield(response).and_return(response)
      end
    end

    context 'when the selected feed entry has an off-origin alternate URL' do
      let(:feed_count) { 1 }
      let(:off_origin_url) { 'https://example.org/post.html' }
      let(:feed_body) do
        feed = {
          'openSearch$totalResults' => { '$t' => '1' },
          'entry' => [{ 'link' => [{ 'rel' => 'alternate', 'href' => off_origin_url }] }]
        }
        "callback(#{JSON.generate('feed' => feed)});"
      end

      before do
        expect(Net::HTTP).not_to receive(:new).with('example.org', any_args)
      end

      it 'loads the trusted post from the refreshed feed' do
        refreshed_response = jsonp_response(feed_body.sub(off_origin_url, show_url))
        expect(page_http).to receive(:request_get).with(feed_path(1)).ordered.and_yield(feed_response)
        expect(page_http).to receive(:request_get).with(feed_path(1)).ordered.and_yield(refreshed_response)
        expect(page_http).to receive(:request_get).with(URI.parse(show_url).request_uri).ordered

        expect(described_class.random.url).to eq(show_url)
      end

      it 'reports the feed error after two off-origin selections' do
        expect(page_http).to receive(:request_get).with(feed_path(1)).twice.and_yield(feed_response)

        expect { described_class.random }.to raise_error(RuntimeError, 'Illustration feed has no usable post URL')
      end
    end

    it 'uses the next alternate link when the first has a malformed URL' do
      feed = {
        'openSearch$totalResults' => { '$t' => feed_count.to_s },
        'entry' => [{ 'link' => [
          { 'rel' => 'alternate', 'href' => 'https://www.irasutoya.com/invalid path.html' },
          { 'rel' => 'alternate', 'href' => show_url }
        ] }]
      }
      response = jsonp_response("callback(#{JSON.generate('feed' => feed)});")
      expect(page_http).to receive(:request_get).with(feed_path(1)).once.ordered
                                                .and_yield(response).and_return(response)
      expect(page_http).to receive(:request_get).with(URI.parse(show_url).request_uri).once.ordered

      expect(described_class.random.url).to eq(show_url)
    end

    it 'skips a null link element and uses the valid alternate link without refreshing the feed' do
      feed = {
        'openSearch$totalResults' => { '$t' => feed_count.to_s },
        'entry' => [{ 'link' => [nil, { 'rel' => 'alternate', 'href' => show_url }] }]
      }
      response = jsonp_response("callback(#{JSON.generate('feed' => feed)});")
      expect(page_http).to receive(:request_get).with(feed_path(1)).once.ordered
                                                .and_yield(response).and_return(response)
      expect(page_http).to receive(:request_get).with(URI.parse(show_url).request_uri).once.ordered

      expect(described_class.random.url).to eq(show_url)
    end

    context 'when the selected feed entry only has malformed link elements' do
      let(:feed_count) { 1 }
      let(:feed_body) do
        feed = {
          'openSearch$totalResults' => { '$t' => '1' },
          'entry' => [{ 'link' => [nil, 'not-a-hash'] }]
        }
        "callback(#{JSON.generate('feed' => feed)});"
      end

      it 'refreshes once and loads the detail page from the refreshed entry' do
        refreshed_feed = {
          'openSearch$totalResults' => { '$t' => '1' },
          'entry' => [{ 'link' => [nil, { 'rel' => 'alternate', 'href' => show_url }] }]
        }
        refreshed_response = jsonp_response("callback(#{JSON.generate('feed' => refreshed_feed)});")
        expect(page_http).to receive(:request_get).with(feed_path(1)).ordered.and_yield(feed_response)
        expect(page_http).to receive(:request_get).with(feed_path(1)).ordered.and_yield(refreshed_response)
        expect(page_http).to receive(:request_get).with(URI.parse(show_url).request_uri).ordered

        expect(described_class.random.url).to eq(show_url)
      end

      it 'reports the feed error after two selections without a usable link' do
        expect(page_http).to receive(:request_get).with(feed_path(1)).twice.and_yield(feed_response)
        expect(page_http).not_to receive(:request_get).with(URI.parse(show_url).request_uri)

        expect { described_class.random }.to raise_error(RuntimeError, 'Illustration feed has no usable post URL')
      end
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

    let(:listing_fixture) { 'list.html' }
    let(:page_http) { stub_page(listing_fixture) }

    before { page_http }

    include_examples 'ordered list results'

    it 'queries the post heading once in each of the twenty result boxes' do
      allow(Nokogiri::HTML).to receive(:parse).and_wrap_original do |parse, *args|
        document = parse.call(*args)
        boxes = document.css('.box')
        expect(boxes.size).to eq(20)
        allow(document).to receive(:css).with('.box').and_return(boxes)
        boxes.each do |box|
          allow(box).to receive(:at_css).and_call_original
          expect(box).to receive(:at_css).with('.boxmeta h2 a').once.and_call_original
        end
        document
      end

      results
    end

    it 'loads links from the initial search URL with their detail and thumbnail URLs' do
      link = results.first

      expect(page_http).to have_received(:request_get).with(URI.parse(search_url).request_uri).once
      expect(link).to be_a(Irasutoya::IrasutoLink)
      expect(link.show_url).to eq('https://www.irasutoya.com/2019/08/blog-post_81.html')
      expect(link.thumbnail_url).to eq(
        'https://1.bp.blogspot.com/-f_bCUFp3lLk/XTKbbODDyQI/AAAAAAABTsY/F65tRwRy-qcIkc8M8HRij85HieUDMMCngCLcBGAs/s72-c/text_company_shigoto_hajime_osame.jpg'
      )
    end

    context 'when the listing has missing or unusable thumbnails' do
      let(:listing_fixture) { 'list_without_thumbnails.html' }

      it 'keeps every card in the results' do
        links = Irasutoya::Irasuto.search(query: query)

        expect(links.map(&:title)).to eq(['Missing thumbnail', 'Empty thumbnail', 'Invalid thumbnail'])
        expect(links.map(&:thumbnail_url)).to eq([nil, nil, nil])
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe Irasutoya::Irasuto do # rubocop:disable Metric/BlockLength
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
    let(:show_uri) { URI.parse('http://www.irasutoya.com/2014/03/blog-post_5924.html') }

    before do
      allow(Random).to receive(:rand).with(feed_count).and_return(0)
      allow(Net::HTTP).to receive(:get_response).with(feed_uri(1)).and_return(feed_response)
      allow(URI).to receive(:parse).and_call_original
      allow(URI).to receive(:parse).with(show_uri.to_s).and_return(show_uri)
      allow(show_uri).to receive(:open).and_return(File.read('spec/files/show.html'))
    end

    def feed_uri(index)
      URI.parse("https://www.irasutoya.com/feeds/posts/summary?start-index=#{index}&max-results=1&alt=json-in-script")
    end

    it 'returns the first entry for a draw of zero without requesting index zero' do
      expect(Net::HTTP).to receive(:get_response).with(feed_uri(1)).once.and_return(feed_response)

      expect(described_class.random.url).to eq(show_uri.to_s)
    end

    it 'requests the last reported index for the highest draw' do
      allow(Random).to receive(:rand).with(feed_count).and_return(feed_count - 1)
      expect(Net::HTTP).to receive(:get_response).with(feed_uri(feed_count)).and_return(feed_response)

      expect(described_class.random.url).to eq(show_uri.to_s)
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
      url = 'http://www.irasutoya.com/2014/03/blog-post_5924.html'

      expect(URI).to have_received(:parse).with(url).once
      expect(irasuto.url).to eq(url)
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
      before do
        allow(show_uri).to receive(:open).and_return(File.read('spec/files/show_multiple_images.html'))
      end

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
    let(:listing_fixture) { 'spec/files/list.html' }
    let(:expected) do
      %w[
        「仕事始め」と「仕事納め」のイラスト文字 福男選びのイラスト 親戚づきあいが苦手な人のイラスト（女性）
        親戚づきあいが苦手な人のイラスト（男性） 親戚の集まりのイラスト お汁粉のイラスト 日の出に照らされるぴょこのイラスト
        電子マネー対応の賽銭箱のイラスト（QRコード） 懐中しるこのイラスト 二人羽織のイラスト（女性）
        獅子舞に頭を噛まれる人のイラスト（女性） 獅子舞に頭を噛まれる人のイラスト（男性） お正月のライン素材（亥年）
        「2019」のイラスト文字 和服を着た高齢の女性のイラスト 和服を着た高齢の男性のイラスト 和服を着た中年女性のイラスト
        和服を着た中年男性のイラスト 書き初めをする猪のイラスト（亥年） 福袋を持った猪のイラスト（亥年）
      ]
    end

    before do
      response = double('HTTP response', charset: 'UTF-8', read: File.read(listing_fixture))
      allow(OpenURI).to receive(:open_uri).and_yield(response)
    end

    it 'should return irasuto links' do
      expect(Irasutoya::Irasuto.search(query: query).size).to eq 20
    end

    it 'should return irasutos' do
      expect(Irasutoya::Irasuto.search(query: query).map(&:title)).to eq expected
    end

    it 'loads detail and thumbnail URLs from paginated search results' do
      link = Irasutoya::Irasuto.search(query: query, page: 2).first
      url = 'https://www.irasutoya.com/search?q=%E6%A4%9C%E7%B4%A2&max-results=20&start=40&by-date=false'

      expect(OpenURI).to have_received(:open_uri).with(URI.parse(url)).once
      expect(OpenURI).to have_received(:open_uri).once
      expect(link).to be_a(Irasutoya::IrasutoLink)
      expect(link.show_url).to eq('https://www.irasutoya.com/2019/08/blog-post_81.html')
      expect(link.thumbnail_url).to eq(
        'https://1.bp.blogspot.com/-f_bCUFp3lLk/XTKbbODDyQI/AAAAAAABTsY/F65tRwRy-qcIkc8M8HRij85HieUDMMCngCLcBGAs/s72-c/text_company_shigoto_hajime_osame.jpg'
      )
    end

    context 'when the listing has missing or unusable thumbnails' do
      let(:listing_fixture) { 'spec/files/list_without_thumbnails.html' }

      it 'keeps every card in the results' do
        links = Irasutoya::Irasuto.search(query: query)

        expect(links.map(&:title)).to eq(['Missing thumbnail', 'Empty thumbnail', 'Invalid thumbnail'])
        expect(links.map(&:thumbnail_url)).to eq([nil, nil, nil])
      end
    end
  end
end

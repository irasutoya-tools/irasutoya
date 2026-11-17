# frozen_string_literal: true

RSpec.describe Irasutoya::Irasuto do # rubocop:disable Metric/BlockLength
  describe '#random' do # rubocop:disable Metrics/BlockLength
    before do
      allow(Net::HTTP).to receive(:get) { File.read('spec/files/posts_summary.jsonp') }
      allow(URI).to receive_message_chain(:parse, :open) { File.read('spec/files/show.html') }
    end

    it 'should return random irasuto' do
      expect(Irasutoya::Irasuto.random).to be_a(Irasutoya::Irasuto)
    end

    it 'should return random irasuto with url' do
      expect(Irasutoya::Irasuto.random.url).to eq('http://www.irasutoya.com/2014/03/blog-post_5924.html')
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
        allow(URI).to receive_message_chain(:parse, :open) {
          File.read('spec/files/show_multiple_images.html')
        }
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

  describe '#search' do
    let(:query) { '検索' }
    let(:results) { described_class.search(query: query) }

    before do
      allow(URI).to receive_message_chain(:parse, :open) { File.read('spec/files/list.html') }
    end

    include_examples 'ordered list results'

    it 'queries anchors once in each of the twenty result boxes' do
      document = Nokogiri::HTML.parse(File.read('spec/files/list.html'))
      boxes = document.css('.box')
      expect(boxes.size).to eq(20)
      allow(described_class).to receive(:fetch_page_and_parse).and_return(document)
      allow(document).to receive(:css).with('.box').and_return(boxes)
      boxes.each { |box| expect(box).to receive(:css).with('a').once.and_call_original }

      results
    end
  end
end

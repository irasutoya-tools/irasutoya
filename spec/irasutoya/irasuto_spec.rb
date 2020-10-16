# frozen_string_literal: true

RSpec.describe Irasutoya::Irasuto do # rubocop:disable Metric/BlockLength
  describe '#random' do
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
      allow(URI).to receive_message_chain(:parse, :open) { File.read('spec/files/list.html') }
    end

    it 'should return irasuto links' do
      expect(Irasutoya::Irasuto.search(query: query).size).to eq 20
    end

    it 'should return irasutos' do
      expect(Irasutoya::Irasuto.search(query: query).map(&:title)).to eq expected
    end
  end
end

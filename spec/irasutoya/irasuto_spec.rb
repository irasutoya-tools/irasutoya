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
      expect(Irasutoya::Irasuto.random.image_url).to eq('http://4.bp.blogspot.com/-7Pa9IazPoII/VGLMYk-SjpI/AAAAAAAAo_s/IryhUKoFJQ0/s400/himan03_youngman.png')
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

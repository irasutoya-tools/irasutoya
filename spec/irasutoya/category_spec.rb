# frozen_string_literal: true

RSpec.describe Irasutoya::Category do # rubocop:disable Metrics/BlockLength
  describe '#all' do # rubocop:disable Metrics/BlockLength
    before do
      allow(URI).to receive_message_chain(:parse, :open) { File.read('spec/files/index.html') }
    end

    let(:expected) do
      %w[
        リクエスト こども 職業 ポーズ 病気 お金 会社 違反 ビジネス 道具 学校 ファッション 食べ物 事故
        趣味 医療 建物 スポーツ スイーツ 家電 おもちゃ 家族 キャラクター 文字 旅行 料理 動物キャラ 日本
        機械 マーク 車 老人 音楽 若者 マナー 飲み物 コンピューター パーティ 家具 医療機器 スマートフォン
        ショッピング 動物 乗り物 友達 食事 夏 生活 インターネット 魚 野菜 軽食 災害 受験 恋愛 人体 冬
        表情 似顔絵 運動 戦争 ペット 美術 掃除 美容 世界 睡眠 お正月 本 風景 就活 科学 犬 虫 あかちゃん
        花 海 鳥 ファンタジー 植物 お年賀状 ウェディング 食材 文房具 物語 猫 介護 調味料 フルーツ 南国
        ランドマーク 環境問題 お風呂 クリスマス テンプレート 夏休み 怪我 引越し スポーツ用具 中年 メディア
        髪 座布団 政治 電車 干支 幼稚園 お祭り 宗教 食器 書類 ゴミ エネルギー オリンピック メッセージ
        映画 楽器 パン 飾り 自転車 農業 お寿司 体育 POP ダンス お葬式 思い出 メタボリック 周辺機器
        食べ物キャラ 棒人間 梅雨 歯 集合 春 お誕生日 英語 運動会 カフェ バレンタイン サッカー 宇宙 吹奏楽
        野球 室内 卒業式 秋 フレーム 爬虫類両生類 トイレ 健康診断 歌 ぴょこ 新社会人 ハロウィン 文化祭
        お弁当 ゴールデンウィーク ライン 天気 深海 夏バテ 洗濯 漁業 古代生物 あいさつ 人体キャラ 貝 地図
        こども職業 裁縫 年の瀬 甲殻類 お花見 世代 仏像 地域キャラ 花火 初詣 音楽家 入学式 こどもの日
        新学期 林業 恐竜 スープ 父の日 忘年会 VR 紅葉 給食 祝日 人工知能 母の日 節分 忍者 クジライルカ
        LGBT ヨガ 乗り物キャラ 大晦日 パラリンピック 動物の顔 日焼け おにぎり ペンギン ホワイトデー 七夕
        書道 陸上 暑中見舞い 星座 成人式 敬老の日 ひな祭り 野菜の切り方 お月見 パターン 伝言メモ 顔アイコン
        LINEスタンプ イースター 勤労感謝の日 ゆめかわ 一筆箋 国旗 トランプ 七五三 メッセージカード 書体
        エイプリルフール 国旗まとめ ペンキ書体 宣伝 白抜き書体 バーサーカー 子供
      ]
    end

    it 'should return all the categories' do
      expect(Irasutoya::Category.all.size).to eq 237
    end

    it 'should return all the category names' do
      expect(Irasutoya::Category.all.map(&:name)).to eq expected
    end
  end

  describe '#fetch_irasuto_links' do
    let(:category) { Irasutoya::Category.new(name: 'お正月', list_url: 'https://www.irasutoya.com/search/label/お正月') }
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
      expect(category.fetch_irasuto_links.size).to eq 20
    end

    it 'should return irasutos' do
      expect(category.fetch_irasuto_links.map(&:title)).to eq expected
    end
  end
end

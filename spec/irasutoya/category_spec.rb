# frozen_string_literal: true

RSpec.describe Irasutoya::Category do # rubocop:disable Metrics/BlockLength
  describe '#all' do # rubocop:disable Metrics/BlockLength
    before do
      stub_page('index.html')
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

    it 'should return all the category titles' do
      expect(Irasutoya::Category.all.map(&:title)).to eq expected
    end
  end

  describe '#fetch_irasuto_links' do
    let(:list_url) { 'https://www.irasutoya.com/search/label/%E3%81%8A%E6%AD%A3%E6%9C%88' }
    let(:category) { Irasutoya::Category.new(title: 'お正月', list_url: list_url) }
    let(:results) { category.fetch_irasuto_links }

    let(:page_http) { stub_page('list.html') }

    before { page_http }

    include_examples 'ordered list results'

    it 'loads detail and thumbnail URLs from the category listing' do
      link = results.first

      expect(page_http).to have_received(:request_get).with(URI.parse(list_url).request_uri).once
      expect(link).to be_a(Irasutoya::IrasutoLink)
      expect(link.show_url).to eq('https://www.irasutoya.com/2019/08/blog-post_81.html')
      expect(link.thumbnail_url).to eq(
        'https://1.bp.blogspot.com/-f_bCUFp3lLk/XTKbbODDyQI/AAAAAAABTsY/F65tRwRy-qcIkc8M8HRij85HieUDMMCngCLcBGAs/s72-c/text_company_shigoto_hajime_osame.jpg'
      )
    end
  end

  it 'fetches a path-relative category result from the redirected listing location' do
    list_url = 'https://www.irasutoya.com/search/label/cats'
    category = described_class.new(title: 'Cats', list_url: list_url)
    http = stub_page('show.html')
    redirect = Net::HTTPFound.new('1.1', '302', 'Found')
    redirect['Location'] = '/archive/2018/09/list.html'
    redirect['Content-Length'] = '0'
    allow(redirect).to receive(:read_body).and_return('')
    allow(http).to receive(:request_get).with('/search/label/cats').and_yield(redirect).and_return(redirect)
    listing = Net::HTTPOK.new('1.1', '200', 'OK')
    html = '<div class="box"><a href="cat-1.html">Image</a><a href="cat-1.html">Cat</a></div>'
    allow(listing).to receive(:body).and_return(html)
    allow(listing).to receive(:read_body).and_yield(html)
    allow(http).to receive(:request_get).with(redirect['Location']).and_yield(listing).and_return(listing)

    expect(category.fetch_irasuto_links.first.fetch_irasuto).to have_attributes(
      url: 'https://www.irasutoya.com/archive/2018/09/cat-1.html', title: '太った少年のイラスト（肥満）'
    )
    expect(http).to have_received(:request_get).with('/archive/2018/09/cat-1.html').once
  end
end

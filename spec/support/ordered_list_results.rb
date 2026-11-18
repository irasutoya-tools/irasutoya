# frozen_string_literal: true

RSpec.shared_examples 'ordered list results' do
  let(:expected_titles) do
    %w[
      「仕事始め」と「仕事納め」のイラスト文字 福男選びのイラスト 親戚づきあいが苦手な人のイラスト（女性）
      親戚づきあいが苦手な人のイラスト（男性） 親戚の集まりのイラスト お汁粉のイラスト 日の出に照らされるぴょこのイラスト
      電子マネー対応の賽銭箱のイラスト（QRコード） 懐中しるこのイラスト 二人羽織のイラスト（女性）
      獅子舞に頭を噛まれる人のイラスト（女性） 獅子舞に頭を噛まれる人のイラスト（男性） お正月のライン素材（亥年）
      「2019」のイラスト文字 和服を着た高齢の女性のイラスト 和服を着た高齢の男性のイラスト 和服を着た中年女性のイラスト
      和服を着た中年男性のイラスト 書き初めをする猪のイラスト（亥年） 福袋を持った猪のイラスト（亥年）
    ]
  end

  let(:expected_urls) do
    %w[
      /2019/08/blog-post_81.html
      /2019/06/blog-post_260.html
      /2019/04/blog-post_189.html
      /2019/04/blog-post_746.html
      /2019/04/blog-post_48.html
      /2019/02/blog-post_86.html
      /2019/01/blog-post.html
      /2018/12/qr.html
      /2018/12/blog-post_992.html
      /2018/11/blog-post_486.html
      /2018/10/blog-post_595.html
      /2018/10/blog-post_465.html
      /2018/10/blog-post_187.html
      /2018/10/2019.html
      /2018/10/blog-post_95.html
      /2018/10/blog-post_609.html
      /2018/10/blog-post_73.html
      /2018/10/blog-post_57.html
      /2018/10/blog-post_17.html
      /2018/10/blog-post_29.html
    ].map { |path| "https://www.irasutoya.com#{path}" }
  end

  it 'returns the fixture titles and URLs in order' do
    expect(results.map { |result| [result.title, result.show_url] }).to eq(expected_titles.zip(expected_urls))
  end
end

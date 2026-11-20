# frozen_string_literal: true

RSpec.describe Irasutoya::IrasutoLink do # rubocop:disable Metrics/BlockLength
  describe '#fetch_irasuto' do # rubocop:disable Metrics/BlockLength
    let(:irasuto_link) { Irasutoya::IrasutoLink.new(title: 'Irasuto', show_url: 'https://www.irasutoya.com/2014/03/blog-post_5924.html') }

    let(:page_http) { stub_page('show.html') }

    before { page_http }

    it 'should return irasuto' do
      expect(irasuto_link.fetch_irasuto).to be_a(Irasutoya::Irasuto)
    end

    it 'should return irasuto with url' do
      irasuto = irasuto_link.fetch_irasuto

      expect(page_http).to have_received(:request_get).with(URI.parse(irasuto_link.show_url).request_uri).once
      expect(irasuto.url).to eq(irasuto_link.show_url)
    end

    it 'should return irasuto with title' do
      expect(irasuto_link.fetch_irasuto.title).to eq('太った少年のイラスト（肥満）')
    end

    it 'should return irasuto with description' do
      expect(irasuto_link.fetch_irasuto.description).to eq('標準体重よりも少し太った小学生～中学生くらいの少年（肥満児）のイラストです。')
    end

    it 'should return irasuto with image_url' do
      expect(irasuto_link.fetch_irasuto.image_url).to eq('https://4.bp.blogspot.com/-7Pa9IazPoII/VGLMYk-SjpI/AAAAAAAAo_s/IryhUKoFJQ0/s400/himan03_youngman.png')
    end

    context 'when the page has invalid, relative, and absolute image sources' do
      let(:irasuto_link) do
        Irasutoya::IrasutoLink.new(title: 'Irasuto', show_url: 'https://www.irasutoya.com/2026/11/detail.html')
      end

      let(:page_http) { stub_page('show_relative_images.html') }

      it 'exposes only valid HTTP and HTTPS images in document order' do
        irasuto = irasuto_link.fetch_irasuto
        expect(irasuto.image_urls).to eq(%w[
          https://www.irasutoya.com/images/root.png
          https://www.irasutoya.com/2026/images/path.png
          https://cdn.example.com/protocol.png
          http://cdn.example.com:80/absolute.png
        ])
        expect(irasuto.image_url).to eq('https://www.irasutoya.com/images/root.png')
      end
    end

    context 'when there are multiple images on a page' do
      before do
        stub_page('show_multiple_images.html')
      end

      it 'should return irasuto (postthumb) with image_url' do
        expect(irasuto_link.fetch_irasuto.image_url).to eq('https://1.bp.blogspot.com/-rchqpx0JGcU/XpKozq0JXAI/AAAAAAABYXA/BnJXB5WNKAcjeFC6_t2XPXwu7wUNAhL3gCNcBGAsYHQ/s195/thumbnail_jitakutaiki.jpg')
      end

      it 'should return multiple irasutos' do
        expect(irasuto_link.fetch_irasuto.image_urls).to match Array
      end

      it 'returns the description from the second separator' do
        description = 'かわいい家のキャラクターと「うちで過ごそう」、「家にいよう」「STAY HOME（ステイホーム）」といった、' \
                      '不要不急の外出を控え自宅待機（外出自粛）を促すメッセージが書かれたイラストです。'
        expect(irasuto_link.fetch_irasuto.description).to eq(description)
      end
    end

    context 'when the page has image groups with headings' do
      let(:page_http) { stub_page('show_image_groups.html') }

      it 'returns the full description after the image groups' do
        description = '既存のイラストと組み合わせて使うことができる、正面、斜め、横、' \
                      '上からみた白いマスクとフェイスシールド（フェイスガード）単体のイラストです。'
        expect(irasuto_link.fetch_irasuto.description).to eq(description)
      end
    end
  end
end

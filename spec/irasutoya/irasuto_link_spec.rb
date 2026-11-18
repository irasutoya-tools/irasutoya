# frozen_string_literal: true

RSpec.describe Irasutoya::IrasutoLink do # rubocop:disable Metrics/BlockLength
  describe '#fetch_irasuto' do # rubocop:disable Metrics/BlockLength
    let(:irasuto_link) { Irasutoya::IrasutoLink.new(title: 'Irasuto', show_url: 'http://example.com') }

    before do
      allow(URI).to receive_message_chain(:parse, :open) { File.read('spec/files/show.html') }
    end

    it 'should return irasuto' do
      expect(irasuto_link.fetch_irasuto).to be_a(Irasutoya::Irasuto)
    end

    it 'should return irasuto with url' do
      irasuto = irasuto_link.fetch_irasuto

      expect(URI).to have_received(:parse).with(irasuto_link.show_url).once
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

    context 'when there are multiple images on a page' do
      before do
        allow(URI).to receive_message_chain(:parse, :open) {
          File.read('spec/files/show_multiple_images.html')
        }
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
      before do
        allow(URI).to receive_message_chain(:parse, :open) { File.read('spec/files/show_image_groups.html') }
      end

      it 'returns the full description after the image groups' do
        description = '既存のイラストと組み合わせて使うことができる、正面、斜め、横、' \
                      '上からみた白いマスクとフェイスシールド（フェイスガード）単体のイラストです。'
        expect(irasuto_link.fetch_irasuto.description).to eq(description)
      end
    end
  end
end

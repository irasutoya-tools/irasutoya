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
      expect(irasuto_link.fetch_irasuto.image_url).to eq('http://4.bp.blogspot.com/-7Pa9IazPoII/VGLMYk-SjpI/AAAAAAAAo_s/IryhUKoFJQ0/s400/himan03_youngman.png')
    end

    context 'when the page has relative and absolute image sources' do
      let(:irasuto_link) do
        Irasutoya::IrasutoLink.new(title: 'Irasuto', show_url: 'https://www.irasutoya.com/2026/11/detail.html')
      end

      before do
        allow(URI).to receive_message_chain(:parse, :open).and_return(<<~HTML)
          <div class="entry">
            <img src="/images/root.png">
            <img src="../images/path.png">
            <img src="//cdn.example.com/protocol.png">
            <img src="http://cdn.example.com:80/absolute.png">
          </div>
        HTML
      end

      it 'exposes resolved image URLs in document order' do
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
    end
  end
end

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
      expect(irasuto_link.fetch_irasuto.url).to eq('http://example.com')
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
    end
  end
end

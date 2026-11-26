# frozen_string_literal: true

require 'socket'
require 'tempfile'
require 'timeout'

RSpec.describe 'Irasutoya::Irasuto#download_image' do # rubocop:disable Metrics/BlockLength
  let(:illustration) do
    Irasutoya::Irasuto.new(
      url: 'https://www.irasutoya.com/2014/03/blog-post.html',
      title: 'Title',
      description: 'Description',
      image_urls: image_urls
    )
  end

  it 'writes the fetched image bytes to the given path' do
    body = "\xFF\xD8\xFF".b
    with_response("Content-Length: #{body.bytesize}", body) do |url|
      self.image_urls = [url]
      Tempfile.create('irasuto-image') do |file|
        illustration.download_image(file.path)

        expect(File.binread(file.path)).to eq(body)
      end
    end
  end

  it 'downloads the image at the given index' do
    second = 'second-image'.b
    with_response("Content-Length: #{second.bytesize}", second) do |second_url|
      self.image_urls = ['http://unused.invalid/first.png', second_url]
      Tempfile.create('irasuto-image') do |file|
        illustration.download_image(file.path, index: 1)

        expect(File.binread(file.path)).to eq(second)
      end
    end
  end

  it 'raises Irasutoya::ResponseTooLargeError and leaves the file untouched when the image exceeds the byte cap' do
    body = 'a lot of image bytes'.b
    with_response("Content-Length: #{body.bytesize}", body) do |url|
      self.image_urls = [url]
      stub_const('Irasutoya::Irasuto::MAX_IMAGE_BYTES', body.bytesize - 1)
      Tempfile.create('irasuto-image') do |file|
        expect { illustration.download_image(file.path) }.to raise_error(Irasutoya::ResponseTooLargeError)
        expect(File.binread(file.path)).to eq('')
      end
    end
  end

  it 'raises ArgumentError for an out-of-range index without making a request' do
    self.image_urls = ['http://127.0.0.1:1/unused']

    Tempfile.create('irasuto-image') do |file|
      expect { illustration.download_image(file.path, index: 1) }
        .to raise_error(ArgumentError, 'No image at index 1')
      expect(File.exist?(file.path)).to be(true)
      expect(File.binread(file.path)).to eq('')
    end
  end

  attr_accessor :image_urls

  def with_response(headers, body, status: '200 OK')
    TCPServer.open('127.0.0.1', 0) do |server|
      worker = Thread.new do
        socket = server.accept
        socket.gets("\r\n\r\n")
        socket.write("HTTP/1.1 #{status}\r\nConnection: close\r\n#{headers}\r\n\r\n", body)
        socket.read
      ensure
        socket&.close
      end
      Timeout.timeout(5) do
        yield "http://127.0.0.1:#{server.addr[1]}/"
        expect(worker.value).to eq('')
      end
    ensure
      worker&.kill
      worker&.join
    end
  end
end

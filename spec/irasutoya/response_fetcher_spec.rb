# frozen_string_literal: true

require 'socket'
require 'timeout'
require 'zlib'

RSpec.describe Irasutoya::ResponseFetcher do
  it 'accepts a multibyte response at the byte limit' do
    body = '日本語'
    with_response("Content-Length: #{body.bytesize}", body) do |url|
      expect(described_class.get(url, max_bytes: body.bytesize)).to eq([body.b, nil])
    end
  end

  it 'closes an oversized chunked response before the server finishes sending it' do
    with_response('Transfer-Encoding: chunked', "4\r\nabcd\r\n4\r\nefgh\r\n") do |url|
      expect { described_class.get(url, max_bytes: 7) }
        .to raise_error(Irasutoya::ResponseTooLargeError, 'HTTP response exceeds the 7-byte limit')
    end
  end

  it 'closes an oversized chunked response before receiving the chunk terminator' do
    with_response('Transfer-Encoding: chunked', "4\r\nabcd\r\n4\r\nefgh") do |url|
      expect { described_class.get(url, max_bytes: 7) }
        .to raise_error(Irasutoya::ResponseTooLargeError, 'HTTP response exceeds the 7-byte limit')
    end
  end

  it 'enforces the limit on decompressed bytes' do
    compressed = Zlib.gzip('a' * 1024)
    headers = "Content-Encoding: gzip\r\nContent-Length: #{compressed.bytesize}"
    with_response(headers, compressed) do |url|
      expect { described_class.get(url, max_bytes: 128) }
        .to raise_error(Irasutoya::ResponseTooLargeError, 'HTTP response exceeds the 128-byte limit')
    end
  end

  it 'follows redirects without downloading their bodies' do
    with_response('Content-Length: 2', 'ok') do |target|
      headers = "Location: #{target}\r\nContent-Length: 9999999"
      with_response(headers, '', status: '302 Found') do |url|
        expect(described_class.get(url, max_bytes: 2)).to eq(['ok', nil])
      end
    end
  end

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

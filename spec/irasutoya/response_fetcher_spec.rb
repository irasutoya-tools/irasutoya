# frozen_string_literal: true

require 'socket'
require 'timeout'
require 'zlib'

RSpec.describe Irasutoya::ResponseFetcher do
  it 'rejects a response that ends before its declared length' do
    with_response('Content-Length: 100', 'partial', close_after_write: true) do |url|
      expect { described_class.get(url, max_bytes: 100) }.to raise_error(EOFError)
    end
  end

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

  it 'decodes a single gzip member at the byte limit' do
    with_gzip_response(Zlib.gzip('first')) do |url|
      expect(described_class.get(url, max_bytes: 5)).to eq(['first', nil])
    end
  end

  it 'decodes concatenated gzip members at the combined byte limit' do
    with_gzip_response(Zlib.gzip('first') + Zlib.gzip('second')) do |url|
      expect(described_class.get(url, max_bytes: 11)).to eq(['firstsecond', nil])
    end
  end

  it 'enforces the byte limit across gzip members' do
    with_gzip_response(Zlib.gzip('first') + Zlib.gzip('second')) do |url|
      expect { described_class.get(url, max_bytes: 6) }
        .to raise_error(Irasutoya::ResponseTooLargeError, 'HTTP response exceeds the 6-byte limit')
    end
  end

  it 'rejects a truncated second gzip member' do
    second = Zlib.gzip('second')
    with_gzip_response(Zlib.gzip('first') + second.byteslice(0...-1)) do |url|
      expect { described_class.get(url, max_bytes: 11) }.to raise_error(Zlib::BufError)
    end
  end

  it 'decodes gzip members split across HTTP chunks' do
    first = Zlib.gzip('first')
    second = Zlib.gzip('second')
    chunks = [first, second.byteslice(0, 1), second.byteslice(1..)]
    body = chunks.map { |chunk| "#{chunk.bytesize.to_s(16)}\r\n#{chunk}\r\n" }.join
    with_response("Content-Encoding: x-gzip\r\nTransfer-Encoding: chunked", body + "0\r\n\r\n") do |url|
      expect(described_class.get(url, max_bytes: 11)).to eq(['firstsecond', nil])
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

  def with_gzip_response(body, &)
    with_response("Content-Encoding: gzip\r\nContent-Length: #{body.bytesize}", body, &)
  end

  def with_response(headers, body, status: '200 OK', close_after_write: false)
    TCPServer.open('127.0.0.1', 0) do |server|
      worker = Thread.new do
        loop do
          socket = server.accept
          socket.gets("\r\n\r\n")
          socket.write("HTTP/1.1 #{status}\r\nConnection: close\r\n#{headers}\r\n\r\n", body)
          break socket.read unless close_after_write
        ensure
          socket&.close
        end
      end
      Timeout.timeout(5) do
        yield "http://127.0.0.1:#{server.addr[1]}/"
        expect(worker.value).to eq('') unless close_after_write
      end
    ensure
      worker&.kill
      worker&.join
    end
  end
end

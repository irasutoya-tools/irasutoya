# frozen_string_literal: true

require 'socket'

RSpec.describe 'Illustration fetch deadlines' do
  let(:server) { TCPServer.new('127.0.0.1', 0) }
  let(:trusted_url) { 'https://www.irasutoya.com' }

  before do
    stub_const('Irasutoya::Modules::HasDocumentFetcher::FETCH_TIMEOUT', 0.5)
    allow(Net::HTTP).to receive(:new).and_call_original
    allow(Net::HTTP).to receive(:new).with('www.irasutoya.com', 443, any_args).and_wrap_original do |new_http, *|
      http = new_http.call('127.0.0.1', server.addr[1], nil)
      allow(http).to receive(:use_ssl=).with(true)
      http
    end
  end

  after do
    @worker&.kill
    @worker&.join
    server.close
  end

  it 'closes an interrupted download and reconnects for the next fetch' do
    stream = lambda do |socket|
      socket.write("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n")
      loop do
        socket.write("1\r\na\r\n")
        break socket.read(1) if IO.select([socket], nil, nil, 0.05)
      end
    rescue Errno::ECONNRESET, Errno::EPIPE
      nil
    end
    serve(stream, response('200 OK', body: File.read('spec/files/show.html'), delay: 0))

    expect_timeout { fetch_illustration('/detail') }
    expect(fetch_illustration('/next').title).to eq('太った少年のイラスト（肥満）')
    expect(@worker.join(1)).to be(@worker)
    expect(@requests.pop(true)).to start_with('GET /detail ')
    expect(@requests.pop(true)).to start_with('GET /next ')
  end

  it 'closes an oversized page and reconnects for the next fetch' do
    html = File.read('spec/files/show.html')
    stub_const('Irasutoya::Modules::HasDocumentFetcher::MAX_HTML_BYTES', html.bytesize)
    stream = lambda do |socket|
      socket.write("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n", "#{(html.bytesize + 1).to_s(16)}\r\n", html, '!')
      socket.read
    end
    serve(stream, response('200 OK', body: html, delay: 0))

    expect { fetch_illustration('/oversized') }.to raise_error(Irasutoya::ResponseTooLargeError)
    expect(fetch_illustration('/next').title).to eq('太った少年のイラスト（肥満）')
    expect(@worker.join(1)).to be(@worker)
  end

  it 'shares the deadline across redirects' do
    serve(
      response('302 Found', location: '/detail', delay: 0.35),
      response('200 OK', body: File.read('spec/files/show.html'), delay: 0.35)
    )

    expect_timeout { fetch_illustration('/redirect') }
    expect(@requests.pop(true)).to start_with('GET /redirect ')
    expect(@requests.pop(true)).to start_with('GET /detail ')
  end

  it 'shares the deadline across both random feed requests and the detail request' do
    feed = JSON.generate(feed: {
                           'openSearch$totalResults' => { '$t' => '2' },
                           'entry' => [{ link: [{ rel: 'alternate', href: "#{trusted_url}/detail" }] }]
                         })
    serve(
      response('200 OK', body: "callback(#{feed});", delay: 0.15),
      response('200 OK', body: "callback(#{feed});", delay: 0.15),
      response('200 OK', body: File.read('spec/files/show.html'), delay: 0.35)
    )
    allow(Random).to receive(:rand).with(2).and_return(1)

    expect_timeout { Irasutoya::Irasuto.random }
    expect(@requests.pop(true)).to start_with('GET /feeds/posts/summary?start-index=1&')
    expect(@requests.pop(true)).to start_with('GET /feeds/posts/summary?start-index=2&')
    expect(@requests.pop(true)).to start_with('GET /detail ')
  end

  def fetch_illustration(path)
    Irasutoya::IrasutoLink.new(title: '', show_url: "#{trusted_url}#{path}").fetch_irasuto
  end

  def expect_timeout(&block)
    expect do
      Timeout.timeout(3, RuntimeError, 'Fetch exceeded the test time limit', &block)
    end.to raise_error(Timeout::Error)
  end

  def serve(*responses)
    listener = server
    @requests = Queue.new
    @worker = Thread.new do
      responses.map do |respond|
        socket = listener.accept
        begin
          @requests << socket.gets
          socket.each_line { |line| break if line == "\r\n" }
          respond.call(socket)
        ensure
          socket.close
        end
      end.last
    end
  end

  def response(status, body: '', location: nil, delay:)
    lambda do |socket|
      sleep delay
      headers = ["HTTP/1.1 #{status}", 'Connection: close', "Content-Length: #{body.bytesize}"]
      headers << "Location: #{location}" if location
      socket.write(headers.join("\r\n") + "\r\n\r\n" + body)
    end
  end
end

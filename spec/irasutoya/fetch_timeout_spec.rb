# frozen_string_literal: true

require 'socket'

RSpec.describe 'Illustration fetch deadlines' do
  let(:server) { TCPServer.new('127.0.0.1', 0) }
  let(:base_url) { "http://127.0.0.1:#{server.addr[1]}" }

  before do
    stub_const('Irasutoya::Modules::HasDocumentFetcher::FETCH_TIMEOUT', 0.5)
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
                           'entry' => [{ link: [{ rel: 'alternate', href: "#{base_url}/detail" }] }]
                         })
    serve(
      response('200 OK', body: "callback(#{feed});", delay: 0.15),
      response('200 OK', body: "callback(#{feed});", delay: 0.15),
      response('200 OK', body: File.read('spec/files/show.html'), delay: 0.35)
    )
    allow(Random).to receive(:rand).with(2).and_return(1)
    allow(Net::HTTP).to receive(:get_response).and_wrap_original do |get_response, uri|
      get_response.call(URI.parse("#{base_url}/feed?#{uri.query}"))
    end

    expect_timeout { Irasutoya::Irasuto.random }
    expect(@requests.pop(true)).to start_with('GET /feed?start-index=1&')
    expect(@requests.pop(true)).to start_with('GET /feed?start-index=2&')
    expect(@requests.pop(true)).to start_with('GET /detail ')
  end

  def fetch_illustration(path)
    Irasutoya::IrasutoLink.new(title: '', show_url: "#{base_url}#{path}").fetch_irasuto
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

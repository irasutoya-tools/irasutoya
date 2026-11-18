# frozen_string_literal: true

require 'socket'
require 'timeout'

RSpec.describe 'Illustration HTTP connections' do
  let(:listener) { TCPServer.new('127.0.0.1', 0) }
  let(:origin) { "http://127.0.0.1:#{listener.addr[1]}" }
  let(:requests) { Queue.new }
  let(:disconnections) { Queue.new }

  around do |example|
    origin
    server = Thread.new do
      loop do
        listener.accept.tap do |socket|
          serve(socket)
          disconnections << socket
        ensure
          socket.close
        end
      end
    end
    Timeout.timeout(10) { example.run }
  ensure
    server&.kill&.join
    listener.close
  end

  it 'parses twenty distinct detail pages over a single TCP connection' do
    titles = (1..20).map { |number| fetch_detail("/detail/#{number}").title }
    received = Array.new(20) { requests.pop }

    expect(titles).to eq((1..20).map { |number| "/detail/#{number}" })
    expect(received.uniq.size).to eq(1)
  end

  it 'reconnects when the server closes an idle connection' do
    fetch_detail('/first')
    original_socket = requests.pop
    original_socket.shutdown(Socket::SHUT_RDWR)
    disconnections.pop

    expect(fetch_detail('/second').title).to eq('/second')
    expect(requests.pop).not_to equal(original_socket)
  end

  it 'uses https_proxy for an HTTPS detail request when http_proxy is unset' do
    allow(ENV).to receive(:[]).and_call_original
    %w[http_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY].each do |name|
      allow(ENV).to receive(:[]).with(name).and_return(nil)
    end
    allow(ENV).to receive(:[]).with('https_proxy').and_return(origin)
    expect(self).to receive(:response_for).with('illustration.invalid:443')
                                         .and_return(http_response('502 Bad Gateway', ''))

    expect { fetch_detail('/detail', from: 'https://illustration.invalid') }
      .to raise_error(Net::HTTPFatalError, /502.*Bad Gateway/)
  end

  it 'closes idle connections without waiting for another request' do
    fetcher = Irasutoya::Modules::HasDocumentFetcher
    session_class = fetcher.const_get(:HttpSession)
    stub_const("#{session_class}::IDLE_TIMEOUT", 0.1)
    pool = fetcher.const_get(:HttpSessionPool).new
    stub_const("#{fetcher}::HTTP_DOCUMENT", fetcher.const_get(:HttpDocument).new(pool))

    fetch_detail('/first')

    expect(disconnections.pop).to equal(requests.pop)
  end

  it 'releases the inherited connection while the child stays alive' do
    skip 'fork is unavailable' unless Process.respond_to?(:_fork)

    fetch_detail('/before-fork')
    original_socket = requests.pop
    reader, writer = IO.pipe
    child = fork do
      writer.close
      reader.read
    end
    reader.close

    expect(fetch_detail('/after-fork').title).to eq('/after-fork')
    expect(requests.pop).to equal(original_socket)
    expect(disconnections.pop).to equal(original_socket)
  ensure
    writer&.close
    Process.wait(child) if child
  end

  it 'follows a relative redirect on the same connection' do
    expect(fetch_detail('/redirect').title).to eq('/destination')
    expect(requests.pop).to equal(requests.pop)
  end

  it 'fetches another origin while the first origin is waiting for a response' do
    other_listener = TCPServer.new('127.0.0.1', 0)
    other_origin = "http://127.0.0.1:#{other_listener.addr[1]}"
    other_server = Thread.new do
      socket = other_listener.accept
      serve(socket)
    ensure
      socket&.close
    end
    release_response = Queue.new
    allow(self).to receive(:response_for).and_wrap_original do |original, path|
      release_response.pop if path == '/slow'
      original.call(path)
    end

    slow_fetch = Thread.new { fetch_detail('/slow') }
    requests.pop
    expect(fetch_detail('/fast', from: other_origin).title).to eq('/fast')
    release_response << true
    expect(slow_fetch.value.title).to eq('/slow')
  ensure
    slow_fetch&.kill&.join
    other_server&.kill&.join
    other_listener&.close
  end

  it 'rejects userinfo before requesting a detail page' do
    expect { fetch_detail('/private', from: origin.sub('://', '://user:pass@')) }
      .to raise_error(ArgumentError, /userinfo not supported/)
    expect(requests).to be_empty
  end

  it 'rejects userinfo before requesting a redirect target' do
    expect { fetch_detail('/redirect-with-userinfo') }.to raise_error(ArgumentError, /userinfo not supported/)
    expect(requests.size).to eq(1)
  end

  it 'uses the response charset to decode the document' do
    expect(fetch_detail('/encoded').title).to eq('珈琲')
  end

  it 'preserves HTTP errors and their response body' do
    expect { fetch_detail('/missing') }.to raise_error(OpenURI::HTTPError, '404 Not Found') do |error|
      expect(error.io.read).to eq('Missing illustration')
    end
  end

  def fetch_detail(path, from: origin)
    Irasutoya::IrasutoLink.new(title: 'Illustration', show_url: from + path).fetch_irasuto
  end

  def serve(socket)
    while (request = socket.gets)
      path = request.split.fetch(1)
      nil until ["\r\n", nil].include?(socket.gets)
      requests << socket
      socket.write(response_for(path))
    end
  end

  def response_for(path)
    return "HTTP/1.1 302 Found\r\nLocation: /destination\r\nContent-Length: 0\r\n\r\n" if path == '/redirect'

    if path == '/redirect-with-userinfo'
      target = origin.sub('://', '://user:pass@') + '/destination'
      return "HTTP/1.1 302 Found\r\nLocation: #{target}\r\nContent-Length: 0\r\n\r\n"
    end

    return http_response('404 Not Found', 'Missing illustration') if path == '/missing'

    title, charset = path == '/encoded' ? ['珈琲', 'Shift_JIS'] : [path, 'UTF-8']
    body = %(<div class="post"><div class="title"><h2>#{title}</h2></div></div>).encode(charset)
    http_response('200 OK', body, charset)
  end

  def http_response(status, body, charset = 'UTF-8')
    "HTTP/1.1 #{status}\r\nContent-Type: text/html; charset=#{charset}\r\nContent-Length: #{body.bytesize}\r\n\r\n#{body}"
  end
end

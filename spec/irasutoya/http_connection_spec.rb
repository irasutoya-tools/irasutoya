# frozen_string_literal: true

require 'socket'
require 'timeout'

RSpec.describe 'Illustration HTTP connections' do
  let(:listener) { TCPServer.new('127.0.0.1', 0) }
  let(:origin) { "http://127.0.0.1:#{listener.addr[1]}" }
  let(:trusted_origin) { 'https://www.irasutoya.com' }
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

  before do
    allow(Net::HTTP).to receive(:new).and_call_original
    allow(Net::HTTP).to receive(:new).with('www.irasutoya.com', 443, nil, nil, nil, nil)
                                    .and_wrap_original do |new_http, *|
      http = new_http.call('127.0.0.1', listener.addr[1], nil)
      allow(http).to receive(:use_ssl=).with(true)
      http
    end
    allow(ENV).to receive(:[]).and_call_original
    %w[https_proxy HTTPS_PROXY].each { |name| allow(ENV).to receive(:[]).with(name).and_return(nil) }
  end

  it 'parses twenty distinct detail pages over a single TCP connection' do
    titles = (1..20).map { |number| fetch_detail("/detail/#{number}").title }
    received = Array.new(20) { requests.pop }

    expect(titles).to eq((1..20).map { |number| "/detail/#{number}" })
    expect(received.uniq.size).to eq(1)
  end

  it 'rejects a truncated page before parsing and accepts a complete page on the next fetch' do
    allow(Nokogiri::HTML).to receive(:parse).and_call_original

    expect { fetch_detail('/truncated') }.to raise_error(EOFError)
    expect(Nokogiri::HTML).not_to have_received(:parse)
    expect(fetch_detail('/complete').title).to eq('/complete')
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
    expect(self).to receive(:response_for).with('www.irasutoya.com:443')
                                         .and_return(http_response('502 Bad Gateway', ''))

    expect { fetch_detail('/detail') }
      .to raise_error(Net::HTTPFatalError, /502.*Bad Gateway/)
  end

  it 'closes idle connections without waiting for another request' do
    fetcher = Irasutoya::Modules::HasDocumentFetcher
    session_class = fetcher.const_get(:HttpSession)
    stub_const("#{session_class}::IDLE_TIMEOUT", 0.1)

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

  it 'closes an unfinished redirect response and fetches the destination' do
    allow(self).to receive(:response_for).with('/unfinished').and_return(unfinished_redirect('/destination'))
    allow(self).to receive(:response_for).with('/destination').and_call_original

    expect(fetch_detail('/unfinished').title).to eq('/destination')
    redirect_socket, destination_socket = Array.new(2) { requests.pop }
    expect(disconnections.pop).to equal(redirect_socket)
    expect(destination_socket).not_to equal(redirect_socket)
  end

  it 'enforces the HTML byte limit at the redirect destination' do
    oversized_body = 'a' * (4 * 1024 * 1024 + 1)
    allow(self).to receive(:response_for).with('/unfinished').and_return(unfinished_redirect('/oversized'))
    allow(self).to receive(:response_for).with('/oversized').and_return(http_response('200 OK', oversized_body))

    expect { fetch_detail('/unfinished') }.to raise_error(Irasutoya::ResponseTooLargeError)
    expect(requests.size).to eq(2)
  end

  it 'resolves relative image URLs against the redirect destination directory' do
    illustration = fetch_detail('/legacy/item.html')
    image_url = "#{trusted_origin}/2024/08/art.png"

    expect(illustration.image_url).to eq(image_url)
    expect(illustration.image_urls).to eq([image_url])
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

    pool = Irasutoya::Modules::HasDocumentFetcher.const_get(:HttpSessionPool).new
    slow_fetch = Thread.new { pool.get(URI.parse("#{origin}/slow")) }
    requests.pop
    expect(pool.get(URI.parse("#{other_origin}/fast")).body).to include('/fast')
    release_response << true
    expect(slow_fetch.value.body).to include('/slow')
  ensure
    slow_fetch&.kill&.join
    other_server&.kill&.join
    other_listener&.close
  end

  it 'rejects userinfo before requesting a detail page' do
    expect { fetch_detail('/private', from: trusted_origin.sub('://', '://user:pass@')) }
      .to raise_error(ArgumentError, /Untrusted Irasutoya page URL/)
    expect(requests).to be_empty
  end

  it 'rejects userinfo before requesting a redirect target' do
    expect { fetch_detail('/redirect-with-userinfo') }.to raise_error(ArgumentError, /Untrusted Irasutoya page URL/)
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

  def fetch_detail(path, from: trusted_origin)
    Irasutoya::IrasutoLink.new(title: 'Illustration', show_url: from + path).fetch_irasuto
  end

  def serve(socket)
    while (request = socket.gets)
      path = request.split.fetch(1)
      nil until ["\r\n", nil].include?(socket.gets)
      requests << socket
      socket.write(response_for(path))
      break if path == '/truncated'
    end
  end

  def response_for(path)
    return "HTTP/1.1 302 Found\r\nLocation: /destination\r\nContent-Length: 0\r\n\r\n" if path == '/redirect'

    if path == '/legacy/item.html'
      return "HTTP/1.1 302 Found\r\nLocation: /2024/08/item.html\r\nContent-Length: 0\r\n\r\n"
    end

    if path == '/redirect-with-userinfo'
      target = trusted_origin.sub('://', '://user:pass@') + '/destination'
      return "HTTP/1.1 302 Found\r\nLocation: #{target}\r\nContent-Length: 0\r\n\r\n"
    end

    return http_response('404 Not Found', 'Missing illustration') if path == '/missing'
    return "HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\n<p>Partial</p>" if path == '/truncated'

    title, charset = path == '/encoded' ? ['珈琲', 'Shift_JIS'] : [path, 'UTF-8']
    body = %(<div class="post"><div class="title"><h2>#{title}</h2></div></div>).encode(charset)
    body << '<div class="entry"><img src="art.png"></div>'
    http_response('200 OK', body, charset)
  end

  def http_response(status, body, charset = 'UTF-8')
    "HTTP/1.1 #{status}\r\nContent-Type: text/html; charset=#{charset}\r\nContent-Length: #{body.bytesize}\r\n\r\n#{body}"
  end

  def unfinished_redirect(target)
    "HTTP/1.1 302 Found\r\nLocation: #{target}\r\nTransfer-Encoding: chunked\r\n\r\n1\r\na\r\n"
  end
end

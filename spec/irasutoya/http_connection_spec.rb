# frozen_string_literal: true

require 'openssl'
require 'socket'
require 'timeout'

RSpec.describe 'Illustration HTTP connections' do
  let(:listener) { TCPServer.new('127.0.0.1', 0) }
  let(:origin) { "http://127.0.0.1:#{listener.addr[1]}" }
  let(:trusted_origin) { 'https://www.irasutoya.com' }
  let(:acceptor) { listener }
  let(:accepted_connections) { Queue.new }
  let(:requests) { Queue.new }
  let(:disconnections) { Queue.new }

  let(:release_body) { Queue.new }
  let(:withheld_bodies) { Queue.new }

  around do |example|
    proxy_setting = /\A(?:https?_proxy|no_proxy|cgi_http_proxy|request_method)\z/i
    original_settings = ENV.select { |name, _| proxy_setting.match?(name) }
    original_settings.each_key { |name| ENV.delete(name) }
    example.run
  ensure
    ENV.keys.select { |name| proxy_setting.match?(name) }.each { |name| ENV.delete(name) }
    ENV.update(original_settings)
  end

  around do |example|
    server_socket = acceptor
    connections = []
    server = Thread.new do
      loop do
        socket = server_socket.accept
        accepted_connections << socket
        connections << Thread.new(socket) do |client|
          serve(client)
        ensure
          client.close
          disconnections << client
        end
      end
    end
    Timeout.timeout(10) { example.run }
  ensure
    server&.kill&.join
    connections&.each { |connection| connection.kill.join }
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
    allow(IPSocket).to receive(:getaddress).and_call_original
    allow(IPSocket).to receive(:getaddress).with('www.irasutoya.com').and_return('192.0.2.1')
  end

  context 'with a local HTTPS server' do
    let(:certificate) { OpenSSL::X509::Certificate.new }
    let(:acceptor) do
      key = OpenSSL::PKey::RSA.new(2048)
      certificate.version = 2
      certificate.serial = 1
      certificate.subject = certificate.issuer = OpenSSL::X509::Name.parse('/CN=localhost')
      certificate.public_key = key
      certificate.not_before = Time.now - 60
      certificate.not_after = Time.now + 3600
      extensions = OpenSSL::X509::ExtensionFactory.new
      extensions.subject_certificate = extensions.issuer_certificate = certificate
      certificate.add_extension(extensions.create_extension('subjectAltName', 'IP:127.0.0.1'))
      certificate.sign(key, OpenSSL::Digest.new('SHA256'))

      context = OpenSSL::SSL::SSLContext.new
      context.cert = certificate
      context.key = key
      OpenSSL::SSL::SSLServer.new(listener, context)
    end

    before do
      allow(Net::HTTP).to receive(:new).with('www.irasutoya.com', 443, nil, nil, nil, nil)
                                       .and_wrap_original do |new_http, *|
        http = new_http.call('127.0.0.1', listener.addr[1], nil)
        http.cert_store = OpenSSL::X509::Store.new.tap { |store| store.add_cert(certificate) }
        http
      end
    end

    it 'fetches the count, selected entry, and larger detail page over one TLS connection' do
      count_path = '/feeds/posts/summary?start-index=1&max-results=1&alt=json-in-script'
      entry_path = count_path.sub('start-index=1', 'start-index=2')
      entry = JSON.generate(feed: {
                              entry: [{ link: [{ rel: 'alternate', href: "#{trusted_origin}/detail" }] }]
                            })
      stub_const('Irasutoya::Irasuto::MAX_FEED_BYTES', entry.bytesize)
      allow(Random).to receive(:rand).with(2).and_return(1)
      count_response = http_response('200 OK', '{"feed":{"openSearch$totalResults":{"$t":"2"}}}')
      expect(self).to receive(:response_for).with(count_path).ordered.and_return(count_response)
      expect(self).to receive(:response_for).with(entry_path).ordered.and_return(http_response('200 OK', entry))
      html = File.read('spec/files/show.html')
      expect(self).to receive(:response_for).with('/detail').ordered.and_return(http_response('200 OK', html))

      expect(Irasutoya::Irasuto.random.title).to eq('太った少年のイラスト（肥満）')
      expect(Array.new(3) { requests.pop }.uniq.size).to eq(1)
    end
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

  it 'times out mid-chunk while the server is still open and reconnects for the next fetch' do
    stub_const('Irasutoya::Modules::HasDocumentFetcher::FETCH_TIMEOUT', 0.2)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    expect { fetch_detail('/stalled-chunk') }.to raise_error(Timeout::Error)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
    expect(elapsed).to be_between(0.15, 0.7)
    stalled_socket = requests.pop(true)
    expect(stalled_socket).not_to be_closed

    expect(fetch_detail('/complete').title).to eq('/complete')
    expect(requests.pop(true)).not_to equal(stalled_socket)
  ensure
    release_body << true
  end

  it 'reconnects when the server closes an idle connection' do
    fetch_detail('/first')
    original_socket = requests.pop
    original_socket.shutdown(Socket::SHUT_RDWR)
    disconnections.pop

    expect(fetch_detail('/second').title).to eq('/second')
    expect(requests.pop).not_to equal(original_socket)
  end

  %w[https_proxy http_proxy].each do |proxy_setting|
    context "with only #{proxy_setting} configured" do
      before { ENV[proxy_setting] = origin }

      it 'uses the same proxy for feed and detail requests' do
        expect(self).to receive(:response_for).with('www.irasutoya.com:443').twice
                                              .and_return(http_response('502 Bad Gateway', ''))

        expect { fetch_feed }.to raise_error(Net::HTTPFatalError, /502.*Bad Gateway/)
        expect { fetch_detail('/detail') }.to raise_error(Net::HTTPFatalError, /502.*Bad Gateway/)
        expect(IPSocket).to have_received(:getaddress).with('www.irasutoya.com').once
      end

      it 'bypasses the proxy for both requests when no_proxy matches the destination port' do
        ENV['no_proxy'] = 'www.irasutoya.com:443'

        expect(fetch_feed.first).to include('/feed')
        expect(fetch_detail('/detail').title).to eq('/detail')
        expect(requests.pop).to equal(requests.pop)
      end
    end
  end

  it 'reuses a host and port bypass across both proxy settings until it expires' do
    ENV.update('https_proxy' => origin, 'http_proxy' => origin, 'no_proxy' => 'www.irasutoya.com:443')
    decisions = Irasutoya.const_get(:HTTP_TRANSPORT).instance_variable_get(:@proxy_decisions)
    allow(decisions).to receive(:monotonic_time).and_return(0.0)

    expect(fetch_detail('/first').title).to eq('/first')
    expect(fetch_detail('/second').title).to eq('/second')
    expect(requests.pop).to equal(requests.pop)
    expect(IPSocket).to have_received(:getaddress).with('www.irasutoya.com').twice

    allow(decisions).to receive(:monotonic_time).and_return(5.0)
    expect(fetch_detail('/third').title).to eq('/third')
    expect(IPSocket).to have_received(:getaddress).with('www.irasutoya.com').exactly(4).times
  end

  it 'resolves a new route when no_proxy changes between requests' do
    ENV.update('http_proxy' => origin, 'no_proxy' => 'www.irasutoya.com:443')

    expect(fetch_detail('/direct').title).to eq('/direct')
    ENV['no_proxy'] = 'www.irasutoya.com:80'
    allow(self).to receive(:response_for).with('www.irasutoya.com:443')
                                         .and_return(http_response('502 Bad Gateway', ''))

    expect { fetch_detail('/proxied') }.to raise_error(Net::HTTPFatalError, /502.*Bad Gateway/)
    expect(IPSocket).to have_received(:getaddress).with('www.irasutoya.com').twice
  end

  it 'uses decoded http_proxy credentials for the HTTPS feed when https_proxy is unset' do
    proxy_url = origin.sub('://', '://proxy%2Buser:p%40ss:word+here@')
    ENV['http_proxy'] = proxy_url
    expect(Net::HTTP).to receive(:new)
      .with('www.irasutoya.com', 443, '127.0.0.1', listener.addr[1], 'proxy+user', 'p@ss:word+here')
      .and_call_original
    allow(self).to receive(:response_for).and_return(http_response('502 Bad Gateway', ''))

    expect { Irasutoya::Irasuto.random }.to raise_error(Net::HTTPFatalError, /502.*Bad Gateway/)
    expect(self).to have_received(:response_for).with('www.irasutoya.com:443')
  end

  it 'closes idle connections without waiting for another request' do
    session_class = Irasutoya.const_get(:HttpSession)
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

  it 'parses a fast detail while an earlier detail is waiting for its body' do
    slow_fetch = Thread.new { fetch_detail('/slow/body') }
    slow_socket = withheld_bodies.pop

    expect(fetch_detail('/fast').title).to eq('/fast')
    expect(requests.pop).to equal(slow_socket)
    expect(requests.pop).not_to equal(slow_socket)
    expect(slow_fetch).to be_alive

    release_body << true
    expect(slow_fetch.value.title).to eq('/slow/body')
  ensure
    slow_fetch&.kill&.join
  end

  it 'counts time waiting at the connection limit toward the fetch deadline' do
    fetcher = Irasutoya::Modules::HasDocumentFetcher
    pool = Irasutoya.const_get(:HttpSessionPool).new(max_connections: 2)
    stub_const('Irasutoya::HTTP_TRANSPORT', pool)

    holders = %w[/slow/body/one /slow/body/two].map { |path| Thread.new { fetch_detail(path) } }
    held_sockets = Array.new(2) { withheld_bodies.pop }
    expect(held_sockets.uniq.size).to eq(2)
    expect(Array.new(2) { requests.pop }).to match_array(held_sockets)

    stub_const("#{fetcher}::FETCH_TIMEOUT", 0.2)
    expect { fetch_detail('/timed-out') }.to raise_error(Timeout::Error)
    expect(requests).to be_empty

    release_body << true << true
    expect(holders.map { |holder| holder.value.title }).to eq(%w[/slow/body/one /slow/body/two])

    expect(fetch_detail('/after-timeout').title).to eq('/after-timeout')
    expect(held_sockets).to include(requests.pop)
  ensure
    holders&.each { |holder| holder.kill.join }
  end

  it 'closes an unfinished redirect response and fetches the destination' do
    allow(self).to receive(:response_for).with('/unfinished').and_return(unfinished_redirect('/destination'))
    allow(self).to receive(:response_for).with('/destination').and_call_original

    expect(fetch_detail('/unfinished').title).to eq('/destination')
    redirect_socket, destination_socket = Array.new(2) { requests.pop }
    expect(disconnections.pop).to equal(redirect_socket)
    expect(destination_socket).not_to equal(redirect_socket)
  end

  it 'reuses a live idle connection after closing an unfinished redirect response' do
    allow(self).to receive(:response_for).with('/unfinished') do
      release_body.pop
      unfinished_redirect('/target')
    end
    allow(self).to receive(:response_for).with('/warm').and_call_original
    allow(self).to receive(:response_for).with('/target').and_call_original

    redirect_fetch = Thread.new { fetch_detail('/unfinished') }
    redirect_socket = requests.pop
    expect(fetch_detail('/warm').title).to eq('/warm')
    warm_socket = requests.pop

    release_body << true
    expect(redirect_fetch.value.title).to eq('/target')
    expect(disconnections.pop).to equal(redirect_socket)
    expect(requests.pop).to equal(warm_socket)
    expect(accepted_connections.size).to eq(2)
  ensure
    redirect_fetch&.kill&.join
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

    pool = Irasutoya.const_get(:HttpSessionPool).new
    slow_fetch = Thread.new { pool.request(URI.parse("#{origin}/slow")) { |_, response| response.read_body } }
    requests.pop
    fast_response = pool.request(URI.parse("#{other_origin}/fast")) { |_, response| response.read_body }
    expect(fast_response.body).to include('/fast')
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

  def fetch_feed
    Irasutoya::ResponseFetcher.get("#{trusted_origin}/feed", max_bytes: 1024)
  end

  def serve(socket)
    while (request = socket.gets)
      path = request.split.fetch(1)
      nil until ["\r\n", nil].include?(socket.gets)
      requests << socket
      response = response_for(path)
      if path == '/stalled-chunk'
        socket.write("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n8\r\na")
        release_body.pop
        break
      elsif path.start_with?('/slow/body')
        headers, body = response.split("\r\n\r\n", 2)
        socket.write(headers, "\r\n\r\n")
        withheld_bodies << socket
        release_body.pop
        socket.write(body)
      else
        socket.write(response)
      end
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
    body = %(<div class="post"><div class="title"><h2>#{title}</h2></div>)
    body << '<div class="entry"><img src="art.png"></div></div>'
    http_response('200 OK', body.encode(charset), charset)
  end

  def http_response(status, body, charset = 'UTF-8')
    "HTTP/1.1 #{status}\r\nContent-Type: text/html; charset=#{charset}\r\n" \
      "Content-Length: #{body.bytesize}\r\n\r\n#{body}"
  end

  def unfinished_redirect(target)
    "HTTP/1.1 302 Found\r\nLocation: #{target}\r\nTransfer-Encoding: chunked\r\n\r\n1\r\na\r\n"
  end
end

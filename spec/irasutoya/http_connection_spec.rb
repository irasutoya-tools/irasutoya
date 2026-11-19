# frozen_string_literal: true

require 'openssl'
require 'socket'
require 'timeout'

RSpec.describe 'Illustration HTTP connections' do
  let(:listener) { TCPServer.new('127.0.0.1', 0) }
  let(:origin) { "http://127.0.0.1:#{listener.addr[1]}" }
  let(:trusted_origin) { 'https://www.irasutoya.com' }
  let(:acceptor) { listener }
  let(:requests) { Queue.new }
  let(:disconnections) { Queue.new }

  around do |example|
    server_socket = acceptor
    server = Thread.new do
      loop do
        server_socket.accept.tap do |socket|
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
      expect(self).to receive(:response_for).with(count_path).ordered
                                           .and_return(http_response('200 OK', '{"feed":{"openSearch$totalResults":{"$t":"2"}}}'))
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
    expect(pool.request(URI.parse("#{other_origin}/fast")) { |_, response| response.read_body }.body).to include('/fast')
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
    end
  end

  def response_for(path)
    return "HTTP/1.1 302 Found\r\nLocation: /destination\r\nContent-Length: 0\r\n\r\n" if path == '/redirect'

    if path == '/redirect-with-userinfo'
      target = trusted_origin.sub('://', '://user:pass@') + '/destination'
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

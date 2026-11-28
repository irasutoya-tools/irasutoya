# frozen_string_literal: true

require 'English'
require 'zlib'

module Irasutoya
  # Net::HTTP retries Timeout::Error, so translate the deadline at the fetch boundary.
  class FetchDeadlineExceeded < StandardError; end

  module ChunkedReadDeadline
    def read(...)
      deadline = $ERROR_INFO
      if deadline.is_a?(FetchDeadlineExceeded)
        # Net::HTTP reads the chunk terminator in an ensure block.
        close
        raise deadline
      end

      super
    end
  end

  class ProxyDecisions
    TTL = 5.0
    MAX_ENTRIES = 32
    PROXY_SETTING = /\A(?:https?_proxy|no_proxy|cgi_http_proxy|request_method)\z/i

    def resolve(uri)
      settings = ENV.select { |name, _| PROXY_SETTING.match?(name) }
      # @type var key: destination
      key = [uri.scheme, uri.hostname, uri.port]
      decision = @lock.synchronize { @entries[key] }
      return decision[2] if decision && decision[0] == settings && decision[1] > monotonic_time

      find_proxy(uri, settings).tap { |proxy| remember(key, settings, proxy) }
    end

    def initialize
      @lock = Mutex.new
      @entries = {}
    end

    private

    def remember(key, settings, proxy)
      @lock.synchronize do
        @entries.delete(key)
        @entries.shift if @entries.size >= MAX_ENTRIES
        @entries[key] = [settings, monotonic_time + TTL, proxy]
      end
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def find_proxy(uri, settings)
      # Use the case-insensitive environment lookup on Windows.
      # @type var env: untyped
      env = File::ALT_SEPARATOR ? ENV : settings
      proxy = uri.find_proxy(env)
      return proxy unless uri.scheme == 'https' && proxy.nil?

      # Preserve the HTTP fallback for TLS while keeping the destination port for no_proxy.
      URI::HTTP.new('http', nil, uri.host, uri.port, nil, nil, nil, nil, nil).find_proxy(env)
    end
  end

  module GzipResponse
    def self.encoded?(response)
      encoding = response['content-encoding']&.downcase
      response.decode_content && !response['content-range'] && %w[gzip x-gzip].include?(encoding)
    end

    def self.read(response, &)
      inflater = Zlib::Inflate.new(Zlib::MAX_WBITS + 16)
      response.decode_content = false
      response.read_body { |chunk| inflate_members(inflater, chunk, &) }
      inflater.finish if response.class.body_permitted? && !inflater.finished?
      response.delete('content-encoding')
    ensure
      inflater&.close
    end

    def self.inflate_members(inflater, chunk)
      until chunk.empty?
        inflater.reset if inflater.finished?
        inflater.inflate(chunk) do |decoded|
          yield decoded
          nil
        end
        break unless inflater.finished?

        # The inflater returns any bytes past the current member from finish.
        chunk = inflater.finish
      end
    end

    private_class_method :inflate_members
  end

  class SessionWaiters
    def initialize
      @queues = {}
    end

    # The caller holds the pool lock for both waiting and notification.
    def wait(key, lock)
      waiter = ConditionVariable.new
      queue = (@queues[key] ||= {})
      queue[waiter] = true
      wait_interruptibly(waiter, lock)
      completed = true
    ensure
      finish_wait(key, queue, waiter, completed)
    end

    def notify(key)
      queue = @queues[key]
      return unless queue

      queue.shift&.first&.signal
      @queues.delete(key) if queue.empty?
    end

    private

    def wait_interruptibly(waiter, lock)
      # @type var thread: untyped
      thread = Thread
      thread.handle_interrupt(FetchDeadlineExceeded => :immediate) { waiter.wait(lock) }
    end

    def finish_wait(key, queue, waiter, completed)
      if queue.delete(waiter)
        @queues.delete(key) if queue.empty?
      elsif !completed
        # Pass on the notification if the selected waiter expired before acquiring.
        notify(key)
      end
    end
  end

  class HttpSessionPool
    MAX_CONNECTIONS_PER_ORIGIN = 4

    def request(uri, &)
      raise ArgumentError, 'Expected an HTTP or HTTPS host' unless uri.hostname

      proxy = @proxy_decisions.resolve(uri)
      raise "Unsupported proxy scheme: #{proxy.scheme}" if proxy && proxy.scheme != 'http'

      # @type var key: origin
      key = [Process.pid, uri.scheme, uri.hostname, uri.port, proxy&.to_s]
      with_session(key) { |session| session.request(uri, proxy, &) }
    end

    def read_body(http, response, max_bytes)
      response.instance_variable_get(:@socket).extend(ChunkedReadDeadline) if response.chunked?
      body = ''.b
      read_response_body(response, body) do |chunk|
        abort_download(http, max_bytes) if body.bytesize + chunk.bytesize > max_bytes

        body << chunk
      end
      body
    rescue IOError => e
      # Net::HTTP can try to read the chunk terminator while unwinding.
      cause = e.cause
      raise(cause.is_a?(ResponseTooLargeError) ? cause : e)
    end

    def close_inherited_connections
      @sessions.each_value { |sessions| sessions.each_key(&:close_inherited_connection) }
      initialize(max_connections: @max_connections)
    end

    def initialize(max_connections: MAX_CONNECTIONS_PER_ORIGIN)
      unless max_connections.is_a?(Integer) && max_connections.positive?
        raise ArgumentError, 'Connection limit must be a positive integer'
      end

      @max_connections = max_connections
      @lock = Mutex.new
      @waiters = SessionWaiters.new
      @sessions = {}
      @proxy_decisions = ProxyDecisions.new
    end

    private

    def read_response_body(response, body, &)
      return response.read_body(&) unless GzipResponse.encoded?(response)

      GzipResponse.read(response, &)
      response['content-length'] = body.bytesize.to_s if response['content-length']
    end

    def abort_download(http, max_bytes)
      http.finish
      raise ResponseTooLargeError, "HTTP response exceeds the #{max_bytes}-byte limit"
    end

    def with_session(key)
      # @type var thread: untyped
      thread = Thread
      thread.handle_interrupt(FetchDeadlineExceeded => :never) do
        session = acquire_session(key)
        begin
          thread.handle_interrupt(FetchDeadlineExceeded => :immediate) { yield session }
        ensure
          release_session(key, session)
        end
      end
    end

    def acquire_session(key)
      @lock.synchronize do
        loop do
          sessions = (@sessions[key] ||= {})
          session = idle_session(sessions)
          session ||= new_session(key) if sessions.size < @max_connections
          next @waiters.wait(key, @lock) unless session

          sessions[session] = true
          return session
        end
      end
    end

    def idle_session(sessions)
      sessions.find { |session, busy| !busy && session.reusable_connection? }&.first || sessions.key(false)
    end

    def new_session(key)
      HttpSession.new { |session| remove_idle_session(key, session) }
    end

    def release_session(key, session)
      @lock.synchronize do
        @sessions.fetch(key)[session] = false
        @waiters.notify(key)
      end
    end

    def remove_idle_session(key, session)
      @lock.synchronize do
        sessions = @sessions.fetch(key)
        return false if sessions.fetch(session)

        # Removing an idle session leaves the same capacity available.
        sessions.delete(session)
        @sessions.delete(key) if sessions.empty?
        true
      end
    end
  end

  class HttpSession
    IDLE_TIMEOUT = 5.0

    def reusable_connection?
      socket = @http&.instance_variable_get(:@socket)
      !socket.nil? && !socket.closed?
    end

    def request(uri, proxy)
      @lock.synchronize do
        http = session_for(uri, proxy)
        response = http.request_get(uri.request_uri) { |reply| yield http, reply }
        completed = true
        response
      ensure
        # An early return or exception can leave an unread body on the wire.
        @http.finish if !completed && @http&.started?
        @idle_since = monotonic_time
      end
    end

    def initialize(&on_idle)
      @lock = Mutex.new
      @on_idle = on_idle
      @idle_since = monotonic_time
      Thread.new { close_when_idle }
    end

    def close_inherited_connection
      # Close only the child's descriptor so TLS shutdown cannot affect the parent.
      buffered_socket = @http&.instance_variable_get(:@socket)
      socket = buffered_socket&.io&.to_io
      socket.close if socket && !socket.closed?
    end

    private

    def session_for(uri, proxy)
      return @http if @http&.started?

      @http = build_http(uri, proxy)
      @http.start
    end

    def build_http(uri, proxy)
      proxy_user, proxy_password = [proxy&.user, proxy&.password].map do |value|
        URI.decode_uri_component(value) if value
      end
      Net::HTTP.new(uri.hostname, uri.port, proxy&.hostname, proxy&.port, proxy_user, proxy_password).tap do |http|
        http.use_ssl = uri.scheme == 'https'
        http.ignore_eof = false
        http.keep_alive_timeout = IDLE_TIMEOUT
      end
    end

    def close_when_idle
      loop do
        remaining = @lock.synchronize { remaining_idle_time }
        break if remaining <= 0

        sleep(remaining)
      end
    end

    def remaining_idle_time
      remaining = IDLE_TIMEOUT - (monotonic_time - @idle_since)
      return remaining if remaining.positive?

      @http.finish if @http&.started?
      @on_idle.call(self) ? remaining : IDLE_TIMEOUT
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end

  HTTP_TRANSPORT = HttpSessionPool.new

  module ForkCleanup
    def _fork
      super.tap { |pid| HTTP_TRANSPORT.close_inherited_connections if pid.zero? }
    end
  end

  Process.singleton_class.prepend(ForkCleanup) if Process.respond_to?(:_fork)
  private_constant :FetchDeadlineExceeded, :ChunkedReadDeadline, :ProxyDecisions, :GzipResponse,
                   :SessionWaiters, :HttpSessionPool, :HttpSession, :HTTP_TRANSPORT, :ForkCleanup
end

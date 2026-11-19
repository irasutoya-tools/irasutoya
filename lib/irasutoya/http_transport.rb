# frozen_string_literal: true

module Irasutoya
  # Net::HTTP retries Timeout::Error, so translate the deadline at the fetch boundary.
  class FetchDeadlineExceeded < StandardError; end

  class HttpSessionPool
    def request(uri, &)
      raise ArgumentError, 'Expected an HTTP or HTTPS host' unless uri.hostname

      proxy = uri.find_proxy
      # @type var key: origin
      key = [Process.pid, uri.scheme, uri.hostname, uri.port, proxy&.to_s]
      with_session(key) { |session| session.request(uri, proxy, &) }
    end

    def read_body(http, response, max_bytes)
      body = ''.b
      response.read_body do |chunk|
        abort_download(http, max_bytes) if body.bytesize + chunk.bytesize > max_bytes

        body << chunk
      end
      body
    rescue IOError => e
      # Net::HTTP can try to read the chunk terminator while unwinding.
      cause = e.cause
      raise cause if cause.is_a?(ResponseTooLargeError)

      raise
    end

    def close_inherited_connections
      @sessions.each_value(&:close_inherited_connection)
      initialize
    end

    def initialize
      @lock = Mutex.new
      @sessions = {}
      @users = Hash.new(0)
    end

    private

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
          @lock.synchronize { @users[key] -= 1 }
        end
      end
    end

    def acquire_session(key)
      @lock.synchronize do
        @users[key] += 1
        @sessions[key] ||= HttpSession.new { remove_idle_session(key) }
      end
    end

    def remove_idle_session(key)
      @lock.synchronize do
        return false unless @users[key].zero?

        @sessions.delete(key)
        @users.delete(key)
        true
      end
    end
  end

  class HttpSession
    IDLE_TIMEOUT = 5.0

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
      raise "Non-HTTP proxy URI: #{proxy}" if proxy && proxy.scheme != 'http'

      proxy_user, proxy_password = proxy&.userinfo&.split(':')
      @http = Net::HTTP.new(uri.hostname, uri.port, proxy&.hostname, proxy&.port, proxy_user, proxy_password)
      @http.use_ssl = uri.scheme == 'https'
      @http.keep_alive_timeout = IDLE_TIMEOUT
      @http.start
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
      @on_idle.call ? remaining : IDLE_TIMEOUT
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
  private_constant :FetchDeadlineExceeded, :HttpSessionPool, :HttpSession, :HTTP_TRANSPORT, :ForkCleanup
end

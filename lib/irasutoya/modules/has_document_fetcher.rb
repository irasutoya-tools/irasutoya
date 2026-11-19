# frozen_string_literal: true

require 'stringio'
require 'timeout'

module Irasutoya
  module Modules
    module HasDocumentFetcher
      FETCH_TIMEOUT = 10
      MAX_HTML_BYTES = 4 * 1024 * 1024

      # Net::HTTP retries Timeout::Error, so translate the deadline at the fetch boundary.
      class FetchDeadlineExceeded < StandardError; end

      def self.included(klass)
        super
        klass.send(:include, Irasutoya::Modules::HasDocumentFetcher::Methods)
        klass.send(:extend, Irasutoya::Modules::HasDocumentFetcher::Methods)
      end

      module Methods
        def fetch_page_and_parse(url)
          with_fetch_timeout do
            HTTP_DOCUMENT.open(URI.parse(url)) { |page| Nokogiri::HTML.parse(page, nil, page.charset) }
          end
        end

        private

        def with_fetch_timeout(&)
          Timeout.timeout(FETCH_TIMEOUT, FetchDeadlineExceeded, &)
        rescue FetchDeadlineExceeded => e
          raise Timeout::Error, e.message
        end
      end

      class HttpDocument
        TRUSTED_HOST = 'www.irasutoya.com'
        REDIRECT_CODES = %w[301 302 303 307 308].freeze
        MAX_REDIRECTS = 10

        def open(uri, &)
          fetch_page(trusted_page_uri(uri), MAX_REDIRECTS, &)
        end

        def initialize(session)
          @session = session
        end

        def close_inherited_connections
          @session.close_inherited_connections
        end

        private

        def fetch_page(uri, redirects_left, &)
          response = @session.get(uri)
          document = response_document(uri, response)
          return yield document if response.is_a?(Net::HTTPSuccess)

          target = redirect(uri, response, document)
          document.close
          raise IOError, 'Too many Irasutoya page redirects' if redirects_left.zero?

          fetch_page(trusted_page_uri(target), redirects_left - 1, &)
        end

        def trusted_page_uri(uri)
          unless uri.is_a?(URI::HTTP) && uri.host&.casecmp?(TRUSTED_HOST) &&
                 uri.port == uri.default_port && uri.userinfo.nil?
            raise ArgumentError, 'Untrusted Irasutoya page URL'
          end

          URI::HTTPS.build(host: TRUSTED_HOST, path: uri.path, query: uri.query)
        end

        def redirect(uri, response, document)
          status = document.status.join(' ')
          raise OpenURI::HTTPError.new(status, document) unless REDIRECT_CODES.include?(response.code)

          location = response['location'] or raise URI::InvalidURIError

          uri.merge(location)
        rescue URI::InvalidURIError
          raise OpenURI::HTTPError.new("#{status} (Invalid Location URI)", document)
        end

        def response_document(uri, response)
          # @type var document: untyped
          document = StringIO.new(response.body.to_s)
          document.tap do
            OpenURI::Meta.init(document)
            document.base_uri = uri
            document.status = [response.code, response.message]
            response.to_hash.each { |name, values| document.meta_add_field2(name, values) }
          end
        end
      end

      class HttpSessionPool
        MAX_CONNECTIONS_PER_ORIGIN = 4

        def get(uri)
          proxy = uri.find_proxy
          # @type var key: origin
          key = [Process.pid, uri.scheme, uri.hostname, uri.port, proxy&.to_s]
          with_session(key) { |session| session.get(uri, proxy) }
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
          @available = ConditionVariable.new
          @sessions = {}
        end

        private

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
              session = sessions.key(false)
              session ||= new_session(key) if sessions.size < @max_connections
              next wait_for_session unless session

              sessions[session] = true
              return session
            end
          end
        end

        def new_session(key)
          HttpSession.new { |session| remove_idle_session(key, session) }
        end

        def wait_for_session
          # A fetch may expire while waiting, before it has a session to release.
          # @type var thread: untyped
          thread = Thread
          thread.handle_interrupt(FetchDeadlineExceeded => :immediate) { @available.wait(@lock) }
        end

        def release_session(key, session)
          @lock.synchronize do
            @sessions.fetch(key)[session] = false
            @available.broadcast
          end
        end

        def remove_idle_session(key, session)
          @lock.synchronize do
            sessions = @sessions.fetch(key)
            return false if sessions.fetch(session)

            sessions.delete(session)
            @sessions.delete(key) if sessions.empty?
            @available.broadcast
            true
          end
        end
      end

      class HttpSession
        IDLE_TIMEOUT = 5.0

        def get(uri, proxy)
          @lock.synchronize do
            http = session_for(uri, proxy)
            http.request_get(uri.request_uri) do |response|
              response.body = ResponseFetcher.read_body(http, response, MAX_HTML_BYTES)
            end
          ensure
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
          @on_idle.call(self) ? remaining : IDLE_TIMEOUT
        end

        def monotonic_time
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end

      HTTP_DOCUMENT = HttpDocument.new(HttpSessionPool.new)

      module ForkCleanup
        def _fork
          super.tap { |pid| HTTP_DOCUMENT.close_inherited_connections if pid.zero? }
        end
      end

      Process.singleton_class.prepend(ForkCleanup) if Process.respond_to?(:_fork)
      private_constant :FetchDeadlineExceeded, :HttpDocument, :HttpSessionPool, :HttpSession, :HTTP_DOCUMENT,
                       :ForkCleanup
    end
  end
end

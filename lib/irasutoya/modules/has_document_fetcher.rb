# frozen_string_literal: true

require 'stringio'

module Irasutoya
  module Modules
    module HasDocumentFetcher
      def self.included(klass)
        super
        klass.send(:include, Irasutoya::Modules::HasDocumentFetcher::Methods)
        klass.send(:extend, Irasutoya::Modules::HasDocumentFetcher::Methods)
      end

      module Methods
        def fetch_page_and_parse(url)
          uri = URI.parse(url)
          return uri.open { |document| parse_document(document) } unless uri.is_a?(URI::HTTP)

          HTTP_DOCUMENT.open(uri) { |document| parse_document(document) }
        end

        private

        def parse_document(document)
          Nokogiri::HTML.parse(document.read, nil, document.charset)
        end
      end

      class HttpDocument
        REDIRECT_CODES = %w[301 302 303 307 308].freeze
        MAX_REDIRECTS = 64

        def open(uri, &)
          # @type var visited: Hash[untyped, bool]
          visited = {}
          loop do
            raise ArgumentError, 'userinfo not supported.  [RFC3986]' if uri.userinfo

            response = @session.get(uri)
            document = response_document(uri, response)
            return yield document if response.is_a?(Net::HTTPSuccess)

            uri = redirect(uri, response, document)
            track_redirect(uri, visited, document)
            return uri.open(&) unless uri.is_a?(URI::HTTP)
          end
        end

        def initialize(session)
          @session = session
        end

        private

        def track_redirect(uri, visited, document)
          raise "HTTP redirection loop: #{uri}" if visited[uri]

          visited[uri] = true
          return if visited.size <= MAX_REDIRECTS

          error = defined?(OpenURI::TooManyRedirects) ? OpenURI::TooManyRedirects : OpenURI::HTTPError
          raise error.new('Too many redirects', document)
        end

        def redirect(uri, response, document)
          status = document.status.join(' ')
          raise OpenURI::HTTPError.new(status, document) unless REDIRECT_CODES.include?(response.code)

          location = response['location'] or raise URI::InvalidURIError

          target = uri.merge(location)
          raise "redirection forbidden: #{uri} -> #{target}" unless OpenURI.redirectable?(uri, target)

          target
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
        def get(uri)
          # @type var key: origin
          key = [Process.pid, uri.scheme, uri.hostname, uri.port]
          session = @lock.synchronize do
            @users[key] += 1
            @sessions[key] ||= HttpSession.new { remove_idle_session(key) }
          end
          session.get(uri) { @lock.synchronize { @users[key] -= 1 } }
        end

        def initialize
          @lock = Mutex.new
          @sessions = {}
          @users = Hash.new(0)
        end

        private

        def remove_idle_session(key)
          @lock.synchronize do
            return unless @users[key].zero?

            @sessions.delete(key)
            @users.delete(key)
          end
        end
      end

      class HttpSession
        IDLE_TIMEOUT = 5.0

        def get(uri)
          @lock.synchronize do
            session_for(uri).get(uri.request_uri)
          ensure
            @idle_since = monotonic_time
            @reaper = Thread.new { close_when_idle } unless @reaper&.alive?
            yield
          end
        end

        def initialize(&on_idle)
          @lock = Mutex.new
          @on_idle = on_idle
        end

        private

        def session_for(uri)
          return @http if @http&.started?

          @http = Net::HTTP.new(uri.hostname, uri.port)
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
          @on_idle.call
          @reaper = nil
          remaining
        end

        def monotonic_time
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end

      HTTP_DOCUMENT = HttpDocument.new(HttpSessionPool.new)
      private_constant :HttpDocument, :HttpSessionPool, :HttpSession, :HTTP_DOCUMENT
    end
  end
end

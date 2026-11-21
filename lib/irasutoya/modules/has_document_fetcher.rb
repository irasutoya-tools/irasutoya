# frozen_string_literal: true

require 'stringio'
require 'timeout'

module Irasutoya
  module Modules
    module HasDocumentFetcher
      TRUSTED_HOST = 'www.irasutoya.com'
      FETCH_TIMEOUT = 10
      MAX_HTML_BYTES = 4 * 1024 * 1024
      REDIRECT_CODES = %w[301 302 303 307 308].freeze

      def self.included(klass)
        super
        klass.send(:include, Irasutoya::Modules::HasDocumentFetcher::Methods)
        klass.send(:extend, Irasutoya::Modules::HasDocumentFetcher::Methods)
      end

      def self.trusted_page_origin?(uri)
        uri.is_a?(URI::HTTP) && uri.host&.casecmp?(TRUSTED_HOST) == true &&
          uri.port == uri.default_port && uri.userinfo.nil?
      end

      module Methods
        def fetch_page_and_parse(url, uri: nil)
          with_fetch_timeout do
            HTTP_DOCUMENT.open(uri || URI.parse(url)) do |page|
              Nokogiri::HTML.parse(page, page.base_uri.to_s, page.charset)
            end
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
        MAX_REDIRECTS = 10

        def open(uri, &)
          fetch_page(trusted_page_uri(uri), MAX_REDIRECTS, &)
        end

        private

        def fetch_page(uri, redirects_left, &)
          response = request(uri)
          document = response_document(uri, response)
          return yield document if response.is_a?(Net::HTTPSuccess)

          target = redirect(uri, response, document)
          document.close
          raise IOError, 'Too many Irasutoya page redirects' if redirects_left.zero?

          fetch_page(trusted_page_uri(target), redirects_left - 1, &)
        end

        def request(uri)
          HTTP_TRANSPORT.request(uri) do |http, reply|
            return reply if unread_redirect_body?(reply)

            reply.body = HTTP_TRANSPORT.read_body(http, reply, MAX_HTML_BYTES)
          end
        end

        def unread_redirect_body?(response)
          REDIRECT_CODES.include?(response.code) &&
            (response['content-length'] != '0' || response.key?('transfer-encoding'))
        end

        def trusted_page_uri(uri)
          raise ArgumentError, 'Untrusted Irasutoya page URL' unless HasDocumentFetcher.trusted_page_origin?(uri)

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
          document = StringIO.new(REDIRECT_CODES.include?(response.code) ? '' : response.body.to_s)
          document.tap do
            OpenURI::Meta.init(document)
            document.base_uri = uri
            document.status = [response.code, response.message]
            response.to_hash.each { |name, values| document.meta_add_field2(name, values) }
          end
        end
      end

      HTTP_DOCUMENT = HttpDocument.new

      private_constant :HttpDocument, :HTTP_DOCUMENT
    end
  end
end

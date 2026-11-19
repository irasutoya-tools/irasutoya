# frozen_string_literal: true

require 'stringio'
require 'timeout'

module Irasutoya
  module Modules
    module HasDocumentFetcher
      FETCH_TIMEOUT = 10
      MAX_HTML_BYTES = 4 * 1024 * 1024

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

        private

        def fetch_page(uri, redirects_left, &)
          response = HTTP_TRANSPORT.request(uri) do |http, reply|
            reply.body = HTTP_TRANSPORT.read_body(http, reply, MAX_HTML_BYTES)
          end
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

      HTTP_DOCUMENT = HttpDocument.new

      private_constant :HttpDocument, :HTTP_DOCUMENT
    end
  end
end

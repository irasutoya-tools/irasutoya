# frozen_string_literal: true

require 'stringio'
require 'timeout'
require 'irasutoya/modules/dual_level'

module Irasutoya
  module Modules
    module HasDocumentFetcher
      include Irasutoya::Modules::DualLevel

      TRUSTED_HOST = 'www.irasutoya.com'
      FETCH_TIMEOUT = 10
      MAX_HTML_BYTES = 4 * 1024 * 1024

      def self.trusted_page_origin?(uri)
        uri.is_a?(URI::HTTP) && uri.host&.casecmp?(TRUSTED_HOST) == true &&
          uri.port == uri.default_port && uri.userinfo.nil?
      end

      def self.trusted_request_url(url)
        uri = URI.parse(url)
        return unless uri.is_a?(URI::HTTP) && trusted_page_origin?(uri)

        "https://#{TRUSTED_HOST}#{uri.request_uri}"
      rescue URI::Error
        nil
      end

      module Methods
        def fetch_page_and_parse(url, uri: nil)
          with_fetch_timeout do
            HTTP_DOCUMENT.open(uri || URI.parse(url)) do |page|
              Nokogiri::HTML.parse(page, page.base_uri.to_s, page.charset { nil })
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
          visited = Set.new
          message = 'Too many Irasutoya page redirects'
          RedirectFollower.follow(
            trusted_page_uri(uri), MAX_REDIRECTS, too_many_redirects_message: message
          ) do |current|
            fetch_page(current, visited, &)
          end
        end

        private

        def fetch_page(uri, visited, &block)
          raise IOError, 'Irasutoya page redirect cycle detected' unless visited.add?(uri.request_uri)

          response = request(uri)
          document = response_document(uri, response)
          return block.call(document) if response.is_a?(Net::HTTPSuccess)

          target = redirect(uri, response, document)
          document.close
          RedirectFollower::Redirect.new(trusted_page_uri(target))
        end

        def request(uri)
          HTTP_TRANSPORT.request(uri) do |http, reply|
            return reply if unread_redirect_body?(reply)

            reply.body = HTTP_TRANSPORT.read_body(http, reply, MAX_HTML_BYTES)
          end
        end

        def unread_redirect_body?(response)
          RedirectFollower::REDIRECT_CODES.include?(response.code) &&
            (response['content-length'] != '0' || response.key?('transfer-encoding'))
        end

        def trusted_page_uri(uri)
          raise ArgumentError, 'Untrusted Irasutoya page URL' unless HasDocumentFetcher.trusted_page_origin?(uri)

          URI::HTTPS.build(host: TRUSTED_HOST, path: uri.path, query: uri.query)
        end

        def redirect(uri, response, document)
          status = document.status.join(' ')
          raise OpenURI::HTTPError.new(status, document) unless RedirectFollower::REDIRECT_CODES.include?(response.code)

          location = response['location']
          raise URI::InvalidURIError if location.nil? || location.strip.empty?

          uri.merge(location)
        rescue URI::InvalidURIError
          raise OpenURI::HTTPError.new("#{status} (Invalid Location URI)", document)
        end

        def response_document(uri, response)
          # @type var document: untyped
          body = RedirectFollower::REDIRECT_CODES.include?(response.code) ? '' : response.body.to_s.dup
          document = StringIO.new(body)
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

# frozen_string_literal: true

module Irasutoya
  module Modules
    module HasDocumentFetcher
      def self.included(klass)
        super
        klass.send(:include, Irasutoya::Modules::HasDocumentFetcher::Methods)
        klass.send(:extend, Irasutoya::Modules::HasDocumentFetcher::Methods)
      end

      module Methods
        TRUSTED_HOST = 'www.irasutoya.com'
        MAX_REDIRECTS = 10

        def fetch_page_and_parse(url)
          fetch_trusted_page(trusted_page_uri(URI.parse(url)), MAX_REDIRECTS)
        end

        private

        def fetch_trusted_page(uri, redirects_left)
          uri.open(redirect: false) { |page| Nokogiri::HTML.parse(page.read, nil, page.charset) }
        rescue OpenURI::HTTPRedirect => e
          e.io.close
          raise IOError, 'Too many Irasutoya page redirects' if redirects_left.zero?

          fetch_trusted_page(trusted_page_uri(e.uri), redirects_left - 1)
        end

        def trusted_page_uri(uri)
          unless uri.is_a?(URI::HTTP) && uri.host&.casecmp?(TRUSTED_HOST) &&
                 uri.port == uri.default_port && uri.userinfo.nil?
            raise ArgumentError, 'Untrusted Irasutoya page URL'
          end

          URI::HTTPS.build(host: TRUSTED_HOST, path: uri.path, query: uri.query)
        end
      end
    end
  end
end

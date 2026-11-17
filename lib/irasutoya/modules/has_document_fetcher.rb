# frozen_string_literal: true

module Irasutoya
  module Modules
    module HasDocumentFetcher
      MAX_HTML_BYTES = 4 * 1024 * 1024

      def self.included(klass)
        super
        klass.send(:include, Irasutoya::Modules::HasDocumentFetcher::Methods)
        klass.send(:extend, Irasutoya::Modules::HasDocumentFetcher::Methods)
      end

      module Methods
        def fetch_page_and_parse(url)
          html, content_type = ResponseFetcher.get(url, max_bytes: MAX_HTML_BYTES)
          Nokogiri::HTML.parse(html, nil, response_charset(content_type))
        end

        private

        def response_charset(content_type)
          charset = content_type&.match(/;\s*charset\s*=\s*(?:"([^"]+)"|([^;\s]+))/i)
          charset&.[](1) || charset&.[](2) || ('utf-8' if content_type&.match?(%r{\Atext/}i))
        end
      end
    end
  end
end

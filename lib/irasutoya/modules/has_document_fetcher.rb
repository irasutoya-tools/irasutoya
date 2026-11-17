# frozen_string_literal: true

require 'timeout'

module Irasutoya
  module Modules
    module HasDocumentFetcher
      FETCH_TIMEOUT = 10

      def self.included(klass)
        super
        klass.send(:include, Irasutoya::Modules::HasDocumentFetcher::Methods)
        klass.send(:extend, Irasutoya::Modules::HasDocumentFetcher::Methods)
      end

      module Methods
        def fetch_page_and_parse(url)
          with_fetch_timeout { read_document(url) }
        end

        private

        def with_fetch_timeout(&)
          Timeout.timeout(FETCH_TIMEOUT, &)
        end

        def read_document(url)
          charset = nil
          html = URI.parse(url).open do |f|
            charset = f.charset
            f.read
          end
          Nokogiri::HTML.parse(html, nil, charset)
        end
      end
    end
  end
end

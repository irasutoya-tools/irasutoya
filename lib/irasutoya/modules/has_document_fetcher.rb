# frozen_string_literal: true

module Irasutoya
  module Modules
    module HasDocumentFetcher
      def self.included(klass)
        klass.send(:include, Irasutoya::Modules::HasDocumentFetcher::Methods)
        klass.send(:extend, Irasutoya::Modules::HasDocumentFetcher::Methods)
      end

      module Methods
        def fetch_page_and_parse(url)
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

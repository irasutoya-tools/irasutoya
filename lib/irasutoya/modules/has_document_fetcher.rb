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
        def fetch_page_and_parse(url)
          URI.parse(url).open do |response|
            Nokogiri::HTML.parse(response, nil, response.charset)
          end
        end
      end
    end
  end
end

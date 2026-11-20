# frozen_string_literal: true

module Irasutoya
  module Modules
    module HasListPageParser
      def self.included(klass)
        super
        klass.send(:include, Irasutoya::Modules::HasListPageParser::Methods)
        klass.send(:extend, Irasutoya::Modules::HasListPageParser::Methods)
      end

      module Methods
        def parse_list_page(document:)
          document.css('.box').filter_map do |box|
            anchors = box.css('a')
            title = anchors[1]&.text
            show_url = anchors.first&.[]('href')
            next if title.to_s.strip.empty? || show_url.to_s.strip.empty?

            { title: title, show_url: show_url }
          end
        end
      end
    end
  end
end

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
          list_page_cards(document: document).to_a
        end

        private

        def list_page_entries(document:)
          return parse_list_page(document: document) unless method(:parse_list_page).owner == Methods

          list_page_cards(document: document)
        end

        def list_page_cards(document:)
          document.css('.box').lazy.filter_map { |box| PrivateMethods.parse_card(box: box) }
        end
      end

      module PrivateMethods
        class << self
          def parse_card(box:)
            anchors = box.css('a')
            title = anchors[1]&.text
            show_url = anchors.first&.[]('href')
            return if title.to_s.strip.empty? || show_url.to_s.strip.empty?

            { title: title, show_url: show_url, thumbnail_url: thumbnail_url_from(box: box) }
          end

          def thumbnail_url_from(box:)
            script = box.at_css('.boxim a script')
            thumbnail_call = %r{\bdocument\.write\(\s*bp_thumbnail_resize\(\s*(["'])(https?://[^"'\s\\]+)\1\s*,}
            url = script&.text&.[](thumbnail_call, 2)
            url if url && URI.parse(url).host
          rescue URI::InvalidURIError
            nil
          end
        end
      end
    end
  end
end

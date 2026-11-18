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
          document.css('.box').map do |box|
            {
              title: PrivateMethods.title_from(box: box),
              show_url: PrivateMethods.show_url_from(box: box),
              thumbnail_url: PrivateMethods.thumbnail_url_from(box: box)
            }
          end
        end
      end

      module PrivateMethods
        class << self
          def title_from(box:)
            box.css('a')[1].text
          end

          def show_url_from(box:)
            box.css('a').first.attribute('href').value
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

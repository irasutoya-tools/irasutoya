# frozen_string_literal: true

module Irasutoya
  module Modules
    module HasShowPageParser
      def self.included(klass)
        klass.send(:include, Irasutoya::Modules::HasShowPageParser::Methods)
        klass.send(:extend, Irasutoya::Modules::HasShowPageParser::Methods)
      end

      module Methods
        def parse_show_page(document:)
          {
            title: title_from(document: document),
            description: description_from(document: document),
            image_url: image_url_from(document: document)
          }
        end

        private

        def title_from(document:)
          document.css('.post').css('.title').search('h2').text.strip
        end

        def description_from(document:)
          document.css('.entry').css('.separator')[1].text.strip
        end

        def image_url_from(document:)
          image = document.css('.entry').search('img').attribute('src').value
          image.chars.first == '/' ? 'http:' + image : image
        end
      end
    end
  end
end

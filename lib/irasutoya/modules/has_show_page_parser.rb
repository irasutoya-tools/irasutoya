# frozen_string_literal: true

module Irasutoya
  module Modules
    module HasShowPageParser
      def self.included(klass)
        super
        klass.send(:include, Irasutoya::Modules::HasShowPageParser::Methods)
        klass.send(:extend, Irasutoya::Modules::HasShowPageParser::Methods)
      end

      module Methods
        def parse_show_page(document:)
          {
            title: PrivateMethods.title_from(document: document),
            description: PrivateMethods.description_from(document: document),
            image_url: PrivateMethods.image_url_from(document: document)
          }
        end
      end

      module PrivateMethods
        class << self
          def title_from(document:)
            document.css('.post').css('.title').search('h2').text.strip
          end

          def description_from(document:)
            document.css('.entry').css('.separator')[1].text.strip
          end

          def image_url_from(document:)
            image = document.css('.entry').search('img').attribute('src').value
            image.chars.first == '/' ? "https:#{image}" : image
          end

          end
        end
      end
    end
  end
end

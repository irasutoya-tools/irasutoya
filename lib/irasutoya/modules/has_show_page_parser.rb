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
            image_urls: PrivateMethods.image_urls_from(document: document)
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

          def image_urls_from(document:)
            sources = document.css('.entry').search('img').collect do |img|
              img[:src]
            end
            sources.collect { |url| url.start_with?('/') ? "https:#{url}" : url }
          end
        end
      end
    end
  end
end

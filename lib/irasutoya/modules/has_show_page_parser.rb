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
        def parse_show_page(document:, url:)
          {
            title: PrivateMethods.title_from(document: document),
            description: PrivateMethods.description_from(document: document),
            image_urls: PrivateMethods.image_urls_from(document: document, url: url)
          }
        end
      end

      module PrivateMethods
        class << self
          def title_from(document:)
            document.css('.post').css('.title').search('h2').text.strip
          end

          def description_from(document:)
            document.css('.entry .separator').last&.text&.strip || ''
          end

          def image_urls_from(document:, url:)
            document.css('.entry').search('img').filter_map do |img|
              source = img[:src]&.strip
              next if source.nil? || source.empty?

              source.match?(/\A[a-z][a-z0-9+.-]*:/i) ? source : URI.join(url, source).to_s
            end
          end
        end
      end
    end
  end
end

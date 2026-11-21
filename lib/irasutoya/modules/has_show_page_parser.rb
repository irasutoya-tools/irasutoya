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
        def parse_show_page(document:, url: (document.url if document.respond_to?(:url)))
          post = document.at_css('.post')
          return { title: '', description: '', image_urls: [] } unless post

          {
            title: post.at_css('.title h2')&.text.to_s.strip,
            description: post.css('.entry .separator').last&.text.to_s.strip,
            image_urls: PrivateMethods.image_urls_from(post: post, url: url)
          }
        end
      end

      module PrivateMethods
        class << self
          def image_urls_from(post:, url:)
            post.css('.entry img').filter_map do |img|
              source = img[:src]&.strip
              next if source.nil? || source.empty?

              resolve_image_url(source, url)
            end
          end

          private

          def resolve_image_url(source, page_url)
            reference = URI.parse(source)
            resolved = reference.absolute? ? reference : URI.join(page_url.to_s, reference)
            return unless resolved.is_a?(URI::HTTP) && !resolved.host.to_s.empty?
            return if one_pixel_blogger_image?(resolved)

            reference.absolute? ? source : resolved.to_s
          rescue URI::Error
            nil
          end

          def one_pixel_blogger_image?(url)
            url.path.to_s.include?('/s1/') &&
              url.host.to_s.match?(/\A(?:blogger\.googleusercontent\.com|\d+\.bp\.blogspot\.com)\z/i)
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Irasutoya
  class Irasuto
    include Modules::HasDocumentFetcher
    include Modules::HasListPageParser
    include Modules::HasShowPageParser

    attr_reader :url, :title, :description, :image_urls, :postthumb_image_url, :image_url, :has_multiple_images

    def initialize(url:, title:, description:, image_urls:)
      @url = url
      @title = title
      @description = description
      @image_urls = image_urls
      @has_multiple_images = image_urls.size > 1
      @postthumb_image_url = image_urls.first if @has_multiple_images
      @image_url = image_urls.first
    end

    class << self
      def random
        PageLoader.load_detail(
          random_url,
          fetch: ->(page_url) { fetch_page_and_parse(page_url) },
          parse: ->(document:) { parse_show_page(document: document) }
        )
      end

      def search(query:, page: 0)
        url = if page.zero?
                "https://www.irasutoya.com/search?q=#{CGI.escape query}"
              else
                "https://www.irasutoya.com/search?q=#{CGI.escape query}&max-results=20&start=#{page * 20}&by-date=false"
              end

        PageLoader.load_list(
          url,
          fetch: ->(page_url) { fetch_page_and_parse(page_url) },
          parse: ->(document:) { parse_list_page(document: document) }
        )
      end

      private

      def random_api_path
        max_index = 22_208
        luck = Random.rand(max_index)
        "/feeds/posts/summary?start-index=#{luck}&max-results=1&alt=json-in-script"
      end

      def random_url
        jsonp = Net::HTTP.get(URI.parse("https://www.irasutoya.com#{random_api_path}"))
        JSON.parse(jsonp[/{.+}/]) # rubocop:disable Style/SingleArgumentDig
            .dig('feed', 'entry')
            .first
            .dig('link')
            .select { |link| link['rel'] == 'alternate' }
            .first
            .dig('href')
      end
    end
  end
end

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
        PageLoader.load_detail(random_url)
      end

      def search(query:, page: 0)
        url = if page.zero?
                "https://www.irasutoya.com/search?q=#{CGI.escape query}"
              else
                "https://www.irasutoya.com/search?q=#{CGI.escape query}&max-results=20&start=#{page * 20}&by-date=false"
              end

        PageLoader.load_list(url)
      end

      private

      def fetch_feed(index)
        url = "https://www.irasutoya.com/feeds/posts/summary?start-index=#{index}&max-results=1&alt=json-in-script"
        response = Net::HTTP.get_response(URI.parse(url))
        response.value
        JSON.parse(response.body[/{.+}/]).fetch('feed')
      end

      def random_url
        feed = fetch_feed(1)
        count = Integer(feed.dig('openSearch$totalResults', '$t'), 10)
        raise 'Illustration feed has no entries' if count.zero?

        index = Random.rand(count) + 1
        feed = fetch_feed(index) unless index == 1
        feed.fetch('entry').first.fetch('link').find { |link| link['rel'] == 'alternate' }.fetch('href')
      end
    end
  end
end

# frozen_string_literal: true

module Irasutoya
  class Irasuto
    include Modules::HasDocumentFetcher
    include Modules::HasListPageParser
    include Modules::HasShowPageParser

    MAX_FEED_BYTES = 1024 * 1024

    attr_reader :url, :title, :description

    def self.from_url(url)
      illustration = PageLoader.load_detail(
        url,
        fetch: ->(page_url) { fetch_page_and_parse(page_url) },
        parse: method(:parse_show_page)
      )
      return illustration if !illustration.title.empty? && illustration.image_url

      raise ArgumentError, 'URL does not point to an Irasutoya illustration post'
    end

    def initialize(url:, title:, description:, image_urls:)
      @url = url
      @title = title
      @description = description
      @image_urls = image_urls.dup
    end

    def image_urls
      @image_urls.dup
    end

    def image_url
      @image_urls.first
    end

    def postthumb_image_url
      image_url if has_multiple_images
    end

    def has_multiple_images # rubocop:disable Naming/PredicateMethod, Naming/PredicatePrefix
      @image_urls.size > 1
    end

    class << self
      def random
        with_fetch_timeout do
          PageLoader.load_detail(
            random_url,
            fetch: ->(page_url) { fetch_page_and_parse(page_url) },
            parse: method(:parse_show_page)
          )
        end
      end

      def search(query:, page: 0)
        url = "https://www.irasutoya.com/search?q=#{CGI.escape query}"
        with_fetch_timeout do
          PageLoader.load_list(
            url,
            page: page,
            fetch: ->(page_url) { fetch_page_and_parse(page_url) },
            parse: ->(document:) { parse_list_page(document: document) }
          )
        end
      end

      private

      def fetch_feed(index)
        url = "https://www.irasutoya.com/feeds/posts/summary?start-index=#{index}&max-results=1&alt=json-in-script"
        body, = ResponseFetcher.get(url, max_bytes: MAX_FEED_BYTES, follow_redirects: false)
        payload = body[/{.+}/] or raise TypeError, 'no implicit conversion of nil into String'
        JSON.parse(payload).fetch('feed')
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

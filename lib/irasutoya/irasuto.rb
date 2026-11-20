# frozen_string_literal: true

module Irasutoya
  class Irasuto # rubocop:disable Metrics/ClassLength
    include Modules::HasDocumentFetcher
    include Modules::HasListPageParser
    include Modules::HasShowPageParser

    MAX_FEED_BYTES = 1024 * 1024
    FEED_COUNT_TTL = 300
    private_constant :FEED_COUNT_TTL

    attr_reader :url, :title, :description

    def self.from_url(url)
      validate_input_url(url)
      PageLoader.load_detail(
        url,
        fetch: ->(page_url) { fetch_page_and_parse(page_url) },
        parse: method(:parse_show_page)
      )
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
        with_fetch_timeout do
          PageLoader.load_list(
            search_url(query),
            page: page,
            fetch: ->(page_url) { fetch_page_and_parse(page_url) },
            parse: ->(document:) { parse_list_page(document: document) }
          )
        end
      end

      def each_search_result(query:, &block)
        return enum_for(:each_search_result, query: query) unless block

        PageLoader.each_list_link(
          search_url(query),
          fetch: ->(page_url) { fetch_page_and_parse(page_url) },
          parse: ->(document:) { parse_list_page(document: document) },
          &block
        )
      end

      private

      def search_url(query)
        "https://www.irasutoya.com/search?q=#{CGI.escape query}"
      end

      def validate_input_url(url)
        URI.parse(url)
      rescue URI::Error
        raise ArgumentError, 'Invalid Irasutoya page URL'
      end

      def fetch_feed(index)
        url = "https://www.irasutoya.com/feeds/posts/summary?start-index=#{index}&max-results=1&alt=json-in-script"
        body, = ResponseFetcher.get(url, max_bytes: MAX_FEED_BYTES, follow_redirects: false)
        payload = body[/{.+}/] or raise TypeError, 'no implicit conversion of nil into String'
        JSON.parse(payload).fetch('feed')
      end

      def random_url
        entry = random_entry || random_entry(refresh: true)
        raise 'Illustration feed has no entries' unless entry

        entry.fetch('link').find { |link| link['rel'] == 'alternate' }.fetch('href')
      end

      def random_entry(refresh: false)
        count = cached_feed_count unless refresh
        count, first_feed = refresh_feed_count unless count
        raise 'Illustration feed has no entries' if count.zero?

        index = Random.rand(count) + 1
        feed = index == 1 && first_feed ? first_feed : fetch_feed(index)
        feed.fetch('entry', []).first
      end

      def cached_feed_count
        count, expires_at = @feed_count_cache
        count if expires_at && feed_count_time < expires_at
      end

      def refresh_feed_count
        feed = fetch_feed(1)
        count = Integer(feed.dig('openSearch$totalResults', '$t'), 10)
        @feed_count_cache = [count, feed_count_time + FEED_COUNT_TTL]
        [count, feed]
      end

      def feed_count_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end

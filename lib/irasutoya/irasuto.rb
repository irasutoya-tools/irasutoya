# frozen_string_literal: true

module Irasutoya
  class Irasuto
    include Modules::HasDocumentFetcher
    include Modules::HasListPageParser
    include Modules::HasShowPageParser

    MAX_FEED_BYTES = 1024 * 1024
    FEED_COUNT_TTL = 300
    FEED_COUNT_CACHE = FeedCountCache.new(ttl: FEED_COUNT_TTL) { fetch_feed_count }

    attr_reader :url, :title, :description

    def self.from_url(url)
      validate_input_url(url)
      load_detail(url)
    end

    def initialize(url:, title:, description:, image_urls:, categories: [])
      @url = url
      @title = title
      @description = description
      @image_urls = image_urls.dup
      @categories = categories.dup
    end

    def categories
      @categories.dup
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
          entry, count = random_entry
          load_initial_random_post(alternate_url(entry)) || load_refreshed_random_post(count)
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
          parse: ->(document:) { list_page_entries(document: document) },
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
        payload = body[/{.+}/m] or raise TypeError, 'no implicit conversion of nil into String'
        JSON.parse(payload).fetch('feed')
      end

      def load_initial_random_post(url)
        load_detail(url) if url
      rescue OpenURI::HTTPError => e
        raise unless %w[404 410].include?(e.io.status.first)

        nil
      end

      def load_refreshed_random_post(stale_count)
        entry, = random_entry(stale_count: stale_count)
        url = alternate_url(entry) or raise 'Illustration feed has no usable post URL'
        load_detail(url)
      end

      def load_detail(url)
        PageLoader.load_detail(
          url,
          fetch: ->(page_url) { fetch_page_and_parse(page_url) },
          parse: method(:parse_show_page)
        )
      end

      def alternate_url(entry)
        links = entry&.[]('link')
        return nil unless links.is_a?(Array)

        link = links.find { |candidate| candidate.is_a?(Hash) && candidate['rel'] == 'alternate' && trusted_feed_url?(candidate['href']) }
        link&.fetch('href')
      end

      def trusted_feed_url?(url)
        return false unless url.is_a?(String)

        Modules::HasDocumentFetcher.trusted_page_origin?(URI.parse(url))
      rescue URI::Error
        false
      end

      def random_entry(stale_count: nil)
        count, first_feed = FEED_COUNT_CACHE.fetch(stale_count: stale_count)
        raise 'Illustration feed has no entries' if count.zero?

        index = Random.rand(count) + 1
        feed = index == 1 && first_feed ? first_feed : fetch_feed(index)
        [feed.fetch('entry', []).first, count]
      end

      def fetch_feed_count
        feed = fetch_feed(1)
        count = Integer(feed.dig('openSearch$totalResults', '$t'), 10)
        [count, feed]
      end
    end
  end
end

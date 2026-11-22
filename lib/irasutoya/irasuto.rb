# frozen_string_literal: true

module Irasutoya
  class Irasuto # rubocop:disable Metrics/ClassLength
    include Modules::HasDocumentFetcher
    include Modules::HasListPageParser
    include Modules::HasShowPageParser

    MAX_FEED_BYTES = 1024 * 1024
    FEED_COUNT_TTL = 300
    FEED_COUNT_LOCK = Mutex.new
    FEED_COUNT_READY = ConditionVariable.new
    FeedCountRefresh = Struct.new(:pid, :result, :error)
    private_constant :FEED_COUNT_TTL, :FEED_COUNT_LOCK, :FEED_COUNT_READY, :FeedCountRefresh

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
          parse: ->(document:) { lazy_list_page(document: document) },
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

      def random_url
        alternate_url(random_entry) || alternate_url(random_entry(refresh: true)) ||
          raise('Illustration feed has no usable post URL')
      end

      def alternate_url(entry)
        links = entry&.[]('link')
        link = links&.find { |candidate| candidate['rel'] == 'alternate' && http_url?(candidate['href']) }
        link&.fetch('href')
      end

      def http_url?(url)
        return false unless url.is_a?(String)

        uri = URI.parse(url)
        uri.is_a?(URI::HTTP) && !uri.host.to_s.empty?
      rescue URI::Error
        false
      end

      def random_entry(refresh: false)
        count, first_feed = feed_count(refresh)
        raise 'Illustration feed has no entries' if count.zero?

        index = Random.rand(count) + 1
        feed = index == 1 && first_feed ? first_feed : fetch_feed(index)
        feed.fetch('entry', []).first
      end

      def cached_feed_count
        count, expires_at = @feed_count_cache
        count if expires_at && feed_count_time < expires_at
      end

      def feed_count(refresh)
        # Keep registration and cleanup atomic with respect to the fetch deadline.
        with_count_interrupt(:never) do
          pending = FEED_COUNT_LOCK.synchronize do
            current = @feed_count_refresh
            return wait_for_feed_count(current) if current && current.pid == Process.pid

            count = cached_feed_count unless refresh
            return [count, nil] if count

            @feed_count_refresh = FeedCountRefresh.new(Process.pid)
          end
          refresh_feed_count(pending)
        end
      end

      def wait_for_feed_count(refresh)
        with_count_interrupt(:immediate) do
          FEED_COUNT_READY.wait(FEED_COUNT_LOCK) while @feed_count_refresh.equal?(refresh)
        end
        error = refresh.error
        raise error if error

        refresh.result || raise(IOError, 'Feed count refresh interrupted')
      end

      def refresh_feed_count(refresh)
        result = with_count_interrupt(:immediate) { fetch_feed_count }
        refresh.result = result
      rescue StandardError => e
        refresh.error = e
        raise
      ensure
        finish_feed_count_refresh
      end

      def finish_feed_count_refresh
        FEED_COUNT_LOCK.synchronize do
          @feed_count_refresh = nil
          FEED_COUNT_READY.broadcast
        end
      end

      def fetch_feed_count
        feed = fetch_feed(1)
        count = Integer(feed.dig('openSearch$totalResults', '$t'), 10)
        @feed_count_cache = count.positive? ? [count, feed_count_time + FEED_COUNT_TTL] : nil
        [count, feed]
      end

      def with_count_interrupt(timing, &)
        # @type var thread: untyped
        thread = Thread
        thread.handle_interrupt(FetchDeadlineExceeded => timing, &)
      end

      def feed_count_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end

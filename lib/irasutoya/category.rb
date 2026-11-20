# frozen_string_literal: true

module Irasutoya
  class Category
    include Modules::HasDocumentFetcher
    include Modules::HasListPageParser

    attr_reader :list_url, :title

    def initialize(title:, list_url:)
      @title = title
      @list_url = list_url
    end

    class << self
      def all
        fetch_page_and_parse('https://www.irasutoya.com')
          .css('#sidebar-wrapper')
          .css('.widget')
          .select { |w| w.search('h2').text == '詳細カテゴリー' }
          .first
          .css('a')
          .filter_map { |a| a['href'] }
          .uniq
          .filter_map { |href| category_from_url(href) }
      end

      private

      def category_from_url(href)
        path = URI.parse(href).path
        label = path.to_s[%r{\A/search/label/([^/]+)\z}, 1]
        return unless label

        new(title: URI.decode_uri_component(label), list_url: href)
      rescue URI::InvalidURIError
        nil
      end
    end

    def fetch_irasuto_links
      PageLoader.load_list(
        list_url,
        fetch: ->(page_url) { fetch_page_and_parse(page_url) },
        parse: ->(document:) { parse_list_page(document: document) }
      )
    end
  end
end

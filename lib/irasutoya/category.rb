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
        homepage_url = 'https://www.irasutoya.com'
        document = fetch_page_and_parse(homepage_url)
        page_url = PageLoader.effective_url(document, homepage_url)
        category_hrefs(document).filter_map { |href| category_from_url(page_url, href) }.uniq(&:list_url)
      end

      private

      def category_hrefs(document)
        widget = document.css('#sidebar-wrapper .widget').find { |item| item.search('h2').text == '詳細カテゴリー' }
        return [] unless widget

        widget.css('a').filter_map { |anchor| anchor['href'] }
      end

      def category_from_url(page_url, href)
        url = URI.join(page_url, href)
        label = url.path.to_s[%r{\A/search/label/([^/]+)\z}, 1]
        return unless label

        new(title: URI.decode_uri_component(label), list_url: url.to_s)
      rescue URI::Error
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

    def each_irasuto_link(&block)
      return enum_for(:each_irasuto_link) unless block

      PageLoader.each_list_link(
        list_url,
        fetch: ->(page_url) { fetch_page_and_parse(page_url) },
        parse: ->(document:) { parse_list_page(document: document) },
        &block
      )
    end
  end
end

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
      def all # rubocop:disable Metrics/AbcSize
        fetch_page_and_parse('https://www.irasutoya.com')
          .css('#sidebar-wrapper')
          .css('.widget')
          .select { |w| w.search('h2').text == '詳細カテゴリー' }
          .first
          .css('a')
          .map { |a| a.attribute('href').value }
          .uniq
          .select { |href| href.include?('label') }
          .map { |href| Category.new(title: CGI.unescape(href.split('/')[5]), list_url: href) }
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

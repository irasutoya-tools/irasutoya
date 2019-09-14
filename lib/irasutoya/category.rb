# frozen_string_literal: true

module Irasutoya
  class Category
    include Modules::HasDocumentFetcher

    attr_reader :list_url, :name

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
          .map { |href| Category.new(name: CGI.unescape(href.split('/')[5]), list_url: href) }
      end
    end

    def initialize(name:, list_url:)
      @name = name
      @list_url = list_url
    end
  end
end

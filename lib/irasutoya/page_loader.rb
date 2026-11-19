# frozen_string_literal: true

module Irasutoya
  module PageLoader
    extend Modules::HasDocumentFetcher::Methods
    extend Modules::HasListPageParser::Methods
    extend Modules::HasShowPageParser::Methods

    def self.load_list(url, page: 0)
      document = fetch_list_page(url, page)
      return [] unless document

      parse_list_page(document: document).map do |parsed|
        IrasutoLink.new(title: parsed.fetch(:title), show_url: parsed.fetch(:show_url))
      end
    end

    def self.load_detail(url, uri: nil)
      document = fetch_page_and_parse(url, uri: uri)
      parsed = parse_show_page(document: document, url: document.url)
      Irasuto.new(url: url, title: parsed.fetch(:title), description: parsed.fetch(:description),
                  image_urls: parsed.fetch(:image_urls))
    end

    def self.fetch_list_page(url, page)
      document = fetch_page_and_parse(url)
      page.times do
        next_href = document.at_css('a.blog-pager-older-link[href]')&.[]('href')
        return nil if next_href.nil? || next_href.empty?

        url = URI.join(url, next_href).to_s
        document = fetch_page_and_parse(url)
      end

      document
    end
    private_class_method :fetch_list_page
  end

  private_constant :PageLoader
end

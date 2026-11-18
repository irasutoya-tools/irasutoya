# frozen_string_literal: true

module Irasutoya
  module PageLoader
    extend Modules::HasDocumentFetcher::Methods
    extend Modules::HasListPageParser::Methods
    extend Modules::HasShowPageParser::Methods

    def self.load_list(url)
      parse_list_page(document: fetch_page_and_parse(url)).map do |parsed|
        IrasutoLink.new(title: parsed.fetch(:title), show_url: parsed.fetch(:show_url))
      end
    end

    def self.load_detail(url)
      parsed = parse_show_page(document: fetch_page_and_parse(url))
      Irasuto.new(url: url, title: parsed.fetch(:title), description: parsed.fetch(:description),
                  image_urls: parsed.fetch(:image_urls))
    end
  end

  private_constant :PageLoader
end

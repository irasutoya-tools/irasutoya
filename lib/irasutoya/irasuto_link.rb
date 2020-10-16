# frozen_string_literal: true

module Irasutoya
  class IrasutoLink
    include Modules::HasDocumentFetcher
    include Modules::HasShowPageParser

    attr_reader :title, :show_url

    def initialize(title:, show_url:)
      @title = title
      @show_url = show_url
    end

    def fetch_irasuto
      document = fetch_page_and_parse(show_url)
      parsed = parse_show_page(document: document)

      Irasuto.new(
        url: show_url,
        title: parsed[:title],
        description: parsed[:description],
        image_urls: parsed[:image_urls]
      )
    end
  end
end

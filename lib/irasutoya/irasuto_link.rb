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
      PageLoader.load_detail(
        show_url,
        fetch: ->(page_url) { fetch_page_and_parse(page_url) },
        parse: ->(document:) { parse_show_page(document: document) }
      )
    end
  end
end

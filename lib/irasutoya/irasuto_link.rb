# frozen_string_literal: true

module Irasutoya
  class IrasutoLink
    include Modules::HasDocumentFetcher
    include Modules::HasShowPageParser

    attr_reader :title, :show_url, :thumbnail_url

    def initialize(title:, show_url:, thumbnail_url: nil)
      @title = title
      @show_url = show_url
      @thumbnail_url = thumbnail_url
    end

    def fetch_irasuto
      PageLoader.load_detail(show_url)
    end
  end
end

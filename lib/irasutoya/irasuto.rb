# frozen_string_literal: true

module Irasutoya
  class Irasuto
    include Modules::HasDocumentFetcher
    include Modules::HasShowPageParser

    attr_reader :url, :title, :description, :image_url

    def initialize(url:, title:, description:, image_url:)
      @url = url
      @title = title
      @description = description
      @image_url = image_url
    end

    class << self
      def random
        url = random_url
        document = fetch_page_and_parse(url)
        parsed = parse_show_page(document: document)

        Irasuto.new(url: url, title: parsed[:title], description: parsed[:description], image_url: parsed[:image_url])
      end

      private

      def random_api_path
        max_index = 22_208
        luck = Random.rand(max_index)
        "/feeds/posts/summary?start-index=#{luck}&max-results=1&alt=json-in-script"
      end

      def random_url
        jsonp = Net::HTTP.get('www.irasutoya.com', random_api_path)
        JSON.parse(jsonp[/{.+}/])
            .dig('feed', 'entry')
            .first
            .dig('link')
            .select { |link| link['rel'] == 'alternate' }
            .first
            .dig('href')
      end
    end
  end
end

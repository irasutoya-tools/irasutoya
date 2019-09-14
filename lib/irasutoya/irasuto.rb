# frozen_string_literal: true

module Irasutoya
  class Irasuto
    include Modules::HasDocumentFetcher

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

        Irasuto.new(
          url: url,
          title: title_from(document: document),
          description: description_from(document: document),
          image_url: image_url_from(document: document)
        )
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

      def title_from(document:)
        document.css('.post').css('.title').search('h2').text.strip
      end

      def description_from(document:)
        document.css('.entry').css('.separator')[1].text.strip
      end

      def image_url_from(document:)
        image = document.css('.entry').search('img').attribute('src').value
        image.chars.first == '/' ? 'http:' + image : image
      end
    end
  end
end

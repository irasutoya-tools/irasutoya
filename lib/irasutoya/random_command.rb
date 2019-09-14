# frozen_string_literal: true

module Irasutoya
  class RandomCommand
    MAX_INDEX = 22_208

    def run
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
      luck = Random.rand(MAX_INDEX)
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

    def fetch_page_and_parse(url)
      charset = nil
      html = URI.parse(url).open do |f|
        charset = f.charset
        f.read
      end
      Nokogiri::HTML.parse(html, nil, charset)
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

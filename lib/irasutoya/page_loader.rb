# frozen_string_literal: true

module Irasutoya
  module PageLoader
    def self.load_list(url, fetch:, parse:)
      parse.call(document: fetch.call(url)).map do |parsed|
        IrasutoLink.new(title: parsed.fetch(:title), show_url: parsed.fetch(:show_url))
      end
    end

    def self.load_detail(url, fetch:, parse:)
      parsed = parse.call(document: fetch.call(url))
      Irasuto.new(url: url, title: parsed.fetch(:title), description: parsed.fetch(:description),
                  image_urls: parsed.fetch(:image_urls))
    end
  end

  private_constant :PageLoader
end

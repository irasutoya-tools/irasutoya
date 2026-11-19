# frozen_string_literal: true

module Irasutoya
  module PageLoader
    def self.load_list(url, fetch:, parse:)
      parse.call(document: fetch.call(url)).map do |parsed|
        IrasutoLink.new(title: parsed.fetch(:title), show_url: parsed.fetch(:show_url))
      end
    end

    def self.load_detail(url, fetch:, parse:)
      document = fetch.call(url)
      parsed = parse_detail(parse, document, url)
      Irasuto.new(url: url, title: parsed.fetch(:title), description: parsed.fetch(:description),
                  image_urls: parsed.fetch(:image_urls))
    end

    def self.parse_detail(parser, document, url)
      accepts_url = parser.parameters.any? do |kind, name|
        kind == :keyrest || (%i[key keyreq].include?(kind) && name == :url)
      end
      accepts_url ? parser.call(document: document, url: url) : parser.call(document: document)
    end
    private_class_method :parse_detail
  end

  private_constant :PageLoader
end

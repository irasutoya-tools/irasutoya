# frozen_string_literal: true

module Irasutoya
  module PageLoader
    def self.load_list(url, fetch:, parse:, page: 0)
      document = fetch_list_page(url, page, fetch)
      return [] unless document

      parse.call(document: document).map do |parsed|
        IrasutoLink.new(title: parsed.fetch(:title), show_url: parsed.fetch(:show_url))
      end
    end

    def self.load_detail(url, fetch:, parse:)
      document = fetch.call(url)
      parsed = parse_detail(parse, document, url)
      title = parsed.fetch(:title)
      image_urls = parsed.fetch(:image_urls)
      raise ArgumentError, 'URL does not point to an Irasutoya illustration post' if title.empty? || !image_urls.first

      Irasuto.new(url: url, title: title, description: parsed.fetch(:description), image_urls: image_urls)
    end

    def self.parse_detail(parser, document, url)
      accepts_url = parser.parameters.any? do |kind, name|
        kind == :keyrest || (%i[key keyreq].include?(kind) && name == :url)
      end
      return parser.call(document: document) unless accepts_url

      page_url = document.url if document.respond_to?(:url)
      parser.call(document: document, url: page_url || url)
    end
    private_class_method :parse_detail

    def self.fetch_list_page(url, page, fetch)
      document = fetch.call(url)
      page.times do
        next_href = document.at_css('a.blog-pager-older-link[href]')&.[]('href')
        return nil if next_href.nil? || next_href.empty?

        url = URI.join(url, next_href).to_s
        document = fetch.call(url)
      end

      document
    end
    private_class_method :fetch_list_page
  end

  private_constant :PageLoader
end

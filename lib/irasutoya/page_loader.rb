# frozen_string_literal: true

module Irasutoya
  module PageLoader
    def self.load_list(url, fetch:, parse:, page: 0)
      listing = fetch_list_page(url, page, fetch)
      return [] unless listing

      document, page_url = listing
      # @type var links: Array[IrasutoLink]
      links = []
      each_page_link(document, page_url, parse) { |link| links << link }
      links
    end

    def self.each_list_link(url, fetch:, parse:, &)
      each_list_page(url, fetch) do |document, page_url|
        each_page_link(document, page_url, parse, &)
      end
    end

    def self.load_detail(url, fetch:, parse:)
      document = fetch.call(url)
      parsed = parse_detail(parse, document, url)
      title = parsed.fetch(:title)
      image_urls = parsed.fetch(:image_urls)
      raise ArgumentError, 'URL does not point to an Irasutoya illustration post' if title.empty? || !image_urls.first

      Irasuto.new(url: url, title: title, description: parsed.fetch(:description), image_urls: image_urls,
                  categories: parsed.fetch(:categories, []))
    end

    def self.effective_url(document, requested_url)
      page_url = document.url if document.respond_to?(:url)
      page_url || requested_url
    end

    def self.parse_detail(parser, document, url)
      accepts_url = parser.parameters.any? do |kind, name|
        kind == :keyrest || (%i[key keyreq].include?(kind) && name == :url)
      end
      return parser.call(document: document) unless accepts_url

      parser.call(document: document, url: effective_url(document, url))
    end
    private_class_method :parse_detail

    def self.each_page_link(document, page_url, parse)
      parse.call(document: document).each do |parsed|
        show_url = resolve_trusted_href(page_url, parsed.fetch(:show_url))
        next unless show_url

        yield IrasutoLink.new(title: parsed.fetch(:title), show_url: show_url, thumbnail_url: parsed[:thumbnail_url])
      end
    end
    private_class_method :each_page_link

    def self.fetch_list_page(url, page, fetch)
      each_list_page(url, fetch) do |document, page_url|
        return [document, page_url] if page <= 0

        page -= 1
      end
      nil
    end
    private_class_method :fetch_list_page

    def self.each_list_page(url, fetch)
      url = without_fragment(url)
      visited = Set.new
      while url && visited.add?(url)
        document = fetch.call(url)
        break unless document

        page_url = without_fragment(effective_url(document, url))
        break if page_url != url && !visited.add?(page_url)

        yield document, page_url
        url = older_page_url(document, page_url)
      end
    end
    private_class_method :each_list_page

    def self.older_page_url(document, page_url)
      href = document.at_css('a.blog-pager-older-link[href]')&.[]('href')
      return if href.nil? || href.empty?

      resolved_url = resolve_trusted_href(page_url, href)
      without_fragment(resolved_url) if resolved_url
    end
    private_class_method :older_page_url

    def self.without_fragment(url)
      url.partition('#').first
    end
    private_class_method :without_fragment

    def self.resolve_trusted_href(page_url, href)
      uri = URI.join(page_url, href)
      uri.to_s if Modules::HasDocumentFetcher.trusted_page_origin?(uri)
    rescue URI::Error
      nil
    end
    private_class_method :resolve_trusted_href
  end

  private_constant :PageLoader
end

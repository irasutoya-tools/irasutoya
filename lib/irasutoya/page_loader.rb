# frozen_string_literal: true

module Irasutoya
  module PageLoader
    def self.load_list(url, fetch:, parse:, page: 0)
      listing = fetch_list_page(url, page, fetch)
      return [] unless listing

      document, page_url = listing
      list_links(document, page_url, parse)
    end

    def self.each_list_link(url, fetch:, parse:, &)
      each_list_page(url, fetch) do |document, page_url|
        list_links(document, page_url, parse).each(&)
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

    def self.list_links(document, page_url, parse)
      parse.call(document: document).filter_map do |parsed|
        show_url = resolve_detail_href(page_url, parsed.fetch(:show_url))
        next unless show_url

        IrasutoLink.new(title: parsed.fetch(:title), show_url: show_url, thumbnail_url: parsed[:thumbnail_url])
      end
    end
    private_class_method :list_links

    def self.fetch_list_page(url, page, fetch)
      visited = Set[url]
      document = fetch.call(url)
      page.times do
        page_url = effective_url(document, url)
        visited.add(page_url)
        url = older_page_url(document, page_url)
        return nil unless url && visited.add?(url)

        document = fetch.call(url)
      end

      [document, effective_url(document, url)] if document
    end
    private_class_method :fetch_list_page

    def self.each_list_page(url, fetch)
      visited = Set.new
      while url && visited.add?(url)
        document = fetch.call(url)
        break unless document

        page_url = effective_url(document, url)
        break if page_url != url && !visited.add?(page_url)

        yield document, page_url
        url = older_page_url(document, page_url)
      end
    end
    private_class_method :each_list_page

    def self.older_page_url(document, page_url)
      href = document.at_css('a.blog-pager-older-link[href]')&.[]('href')
      URI.join(page_url, href).to_s unless href.nil? || href.empty?
    rescue URI::Error
      nil
    end
    private_class_method :older_page_url

    def self.resolve_detail_href(page_url, href)
      uri = URI.join(page_url, href)
      uri.to_s if Modules::HasDocumentFetcher.trusted_page_origin?(uri)
    rescue URI::Error
      nil
    end
    private_class_method :resolve_detail_href
  end

  private_constant :PageLoader
end

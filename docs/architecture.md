# Architecture

## Follow a search from results to details

1. [`Irasuto.search`][irasuto] builds the search URL and passes it to
   [`PageLoader`][loader]. The loader follows older-results links to reach the
   requested page. Lazy search and [category browsing][category] use the same
   loader to fetch pages as the caller consumes results.
2. [`HasDocumentFetcher`][fetcher] fetches HTML and parses it with Nokogiri.
   [`HasListPageParser`][list-parser] extracts each listing card's title,
   detail link, and optional thumbnail. The loader resolves relative detail
   links against the listing URL and builds `IrasutoLink` objects.
3. [`IrasutoLink#fetch_irasuto`][link] hands the selected URL back to the loader.
   [`HasShowPageParser`][detail-parser] extracts the title, description, and
   image URLs. The loader requires a title and at least one image URL before
   building an `Irasuto`. Direct URL lookups use the same detail loader.

## Follow an HTTP request

The HTML fetcher validates page URLs and redirect targets before fetching them.
`Irasuto.random` uses [`ResponseFetcher`][response] to read the posts feed, then
loads the selected post through the detail loader. Both fetchers use the
[shared HTTP transport][transport], which pools Net::HTTP connections and
enforces the caller's response size limit while reading the body.

## Find the relevant specs

- For listing cards or thumbnails, start with the [incomplete listing card
  specs][listing-spec]. For page navigation, see the [search pagination
  specs][pagination-spec].
- For detail fields and image extraction, start with the [illustration
  specs][detail-spec].
- For request deadlines and connection reuse, see the [fetch timeout
  specs][timeout-spec] and [HTTP connection specs][connection-spec].

The parser specs use saved pages under [`spec/files/`][fixtures]. See
[Contributing][contributing] for setup and check commands.

[irasuto]: ../lib/irasutoya/irasuto.rb
[loader]: ../lib/irasutoya/page_loader.rb
[category]: ../lib/irasutoya/category.rb
[fetcher]: ../lib/irasutoya/modules/has_document_fetcher.rb
[list-parser]: ../lib/irasutoya/modules/has_list_page_parser.rb
[link]: ../lib/irasutoya/irasuto_link.rb
[detail-parser]: ../lib/irasutoya/modules/has_show_page_parser.rb
[response]: ../lib/irasutoya/response_fetcher.rb
[transport]: ../lib/irasutoya/http_transport.rb
[listing-spec]: ../spec/irasutoya/incomplete_list_cards_spec.rb
[pagination-spec]: ../spec/irasutoya/search_pagination_spec.rb
[detail-spec]: ../spec/irasutoya/irasuto_spec.rb
[timeout-spec]: ../spec/irasutoya/fetch_timeout_spec.rb
[connection-spec]: ../spec/irasutoya/http_connection_spec.rb
[fixtures]: ../spec/files/
[contributing]: ../CONTRIBUTING.md

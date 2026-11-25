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

`Irasuto.random` picks an entry's index from the feed's post count. [`FeedCountCache`][feed-count-cache]
coalesces concurrent count refreshes behind a short-lived cache, so simultaneous
`Irasuto.random` calls share one refresh instead of issuing concurrent feed requests.

## Find the relevant specs

- For listing cards or thumbnails, start with the [incomplete listing card
  specs][listing-spec]. For page navigation, see the [search pagination
  specs][pagination-spec].
- For detail fields and image extraction, start with the [illustration
  specs][detail-spec].
- For request deadlines and connection reuse, see the [fetch timeout
  specs][timeout-spec] and [HTTP connection specs][connection-spec].
- For feed-count caching and coalescing, see the [feed count cache
  specs][feed-count-cache-spec] and [random feed count specs][random-feed-count-spec].

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
[feed-count-cache]: ../lib/irasutoya/feed_count_cache.rb
[listing-spec]: https://github.com/irasutoya-tools/irasutoya/blob/master/spec/irasutoya/incomplete_list_cards_spec.rb
[pagination-spec]: https://github.com/irasutoya-tools/irasutoya/blob/master/spec/irasutoya/search_pagination_spec.rb
[detail-spec]: https://github.com/irasutoya-tools/irasutoya/blob/master/spec/irasutoya/irasuto_spec.rb
[timeout-spec]: https://github.com/irasutoya-tools/irasutoya/blob/master/spec/irasutoya/fetch_timeout_spec.rb
[connection-spec]: https://github.com/irasutoya-tools/irasutoya/blob/master/spec/irasutoya/http_connection_spec.rb
[feed-count-cache-spec]: https://github.com/irasutoya-tools/irasutoya/blob/master/spec/irasutoya/feed_count_cache_spec.rb
[random-feed-count-spec]: https://github.com/irasutoya-tools/irasutoya/blob/master/spec/irasutoya/random_feed_count_spec.rb
[fixtures]: https://github.com/irasutoya-tools/irasutoya/tree/master/spec/files
[contributing]: ../CONTRIBUTING.md

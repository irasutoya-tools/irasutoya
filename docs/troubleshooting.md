# Troubleshooting

## Why did search return an empty array?

`Irasutoya::Irasuto.search` uses zero-based page numbers. Try `page: 0` to check
the first page, or try a broader query. A page beyond the last result also
returns an empty array. To browse results without tracking page numbers, use
`Irasutoya::Irasuto.each_search_result(query: ...)`.

## Why is the thumbnail URL missing?

Some listing cards have no usable thumbnail. When `link.thumbnail_url` is
`nil`, load the detail page with `link.fetch_irasuto` and use the returned
illustration's `image_url`.

## Why did a search raise `Timeout::Error`?

A search has a 10-second deadline for the entire call, including any earlier
pages it must fetch to reach the requested page. When browsing results, use
`each_search_result` with `take` or `find` to stop as soon as you have what you
need. Each listing page fetched by the enumerator gets its own deadline.

## Why did `from_url` raise `ArgumentError`?

Use an absolute post URL on `www.irasutoya.com` with the default port and no
embedded credentials. If you already have a search result, pass its `show_url`
or call `fetch_irasuto` on it directly. A page that loads without a post title
or an image URL also raises `ArgumentError`.

## Why did `download_image` raise `ArgumentError`?

The `index` keyword must be a valid index into `image_urls`. Check
`illustration.image_urls.size` (or use the default `index: 0`) before
downloading an image at another index.

## Why did `download_image` raise `Irasutoya::ResponseTooLargeError`?

The image exceeded the 10 MiB download cap. This mirrors the caps already
applied to HTML and feed fetches; see [Fetch behavior](usage.md#fetch-behavior).

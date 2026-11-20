# Ruby API reference

Load the gem with `require 'irasutoya'`. The classes below are in the `Irasutoya` namespace.

## Find illustrations

| Method | Returns | Behavior |
| --- | --- | --- |
| `Irasuto.search(query:, page: 0)` | Array of `IrasutoLink` | Searches for a string query. `page: 0` is the first page. Each additional page follows one older-results link. If the requested page is beyond the last page or an older-results link points to a page already fetched in this search, the result is an empty array. |
| `Irasuto.each_search_result(query:)` | Enumerator without a block | Yields search results across successive listing pages. |
| `Irasuto.random` | `Irasuto` | Chooses an entry from the posts feed and loads its detail page. |
| `Irasuto.from_url(url)` | `Irasuto` | Loads an illustration directly from a post URL. |
| `Category.all` | Array of `Category` | Reads the site's category list. |
| `category.fetch_irasuto_links` | Array of `IrasutoLink` | Loads the first listing page for a category. Each category exposes `title` and `list_url`. |
| `category.each_irasuto_link` | Enumerator without a block | Yields category results across successive listing pages. |

An `IrasutoLink` exposes `title`, `show_url`, and `thumbnail_url`. The thumbnail URL preserves the size specified in the listing and is `nil` when the card has no usable thumbnail. Call `link.fetch_irasuto` to load its detail page and get an `Irasuto`.

## Read illustration details

| Attribute | Value |
| --- | --- |
| `url`, `title`, `description` | The post URL, title, and description. |
| `image_urls` | An array of image URLs in the order extracted from the page. |
| `image_url` | The first image URL, or `nil` when there are no images. |
| `has_multiple_images` | `true` when the post has more than one image. |
| `postthumb_image_url` | The first image URL for a post with multiple images, or `nil` otherwise. |

## Fetch behavior

- `from_url` accepts absolute HTTP and HTTPS URLs on `www.irasutoya.com` with the default port and no embedded credentials. The request uses HTTPS. A relative URL, an untrusted origin, or a successfully loaded page without a title or image URL raises `ArgumentError`.
- Fetches raise `Timeout::Error` when they exceed the 10-second limit. A call to `Irasuto.search` shares one deadline across its page requests. Lazy enumeration gives each listing page its own deadline. A random lookup shares one deadline across its feed and detail requests.
- Lazy enumeration stops at the end of the results or when pagination revisits a listing page.
- HTML responses are capped at 4 MiB and feed responses at 1 MiB. The limits apply after decompression, and exceeding either limit raises `Irasutoya::ResponseTooLargeError`.

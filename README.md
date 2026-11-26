# Irasutoya

[![test](https://github.com/irasutoya-tools/irasutoya/actions/workflows/test.yml/badge.svg)](https://github.com/irasutoya-tools/irasutoya/actions/workflows/test.yml)
[![Gem Version](https://badge.fury.io/rb/irasutoya.svg)](https://badge.fury.io/rb/irasutoya)
[![Code Climate](https://codeclimate.com/github/irasutoya-tools/irasutoya/badges/gpa.svg)](https://codeclimate.com/github/irasutoya-tools/irasutoya)
[![Libraries.io dependency status for GitHub repo](https://img.shields.io/librariesio/github/irasutoya-tools/irasutoya.svg)](https://libraries.io/github/irasutoya-tools/irasutoya)
![](http://ruby-gem-downloads-badge.herokuapp.com/irasutoya?type=total)
![GitHub](https://img.shields.io/github/license/irasutoya-tools/irasutoya.svg)

<p align="center">
  <img src="https://1.bp.blogspot.com/-QU1PrEXerMg/XWS5ZxD-tsI/AAAAAAABUR4/1EuTP776BowewKdMAgnAUpUB5m3O7ve-ACLcBGAs/s1600/computer_screen_programming.png" width="400"/>
</p>

`Irasutoya` is ruby library for [いらすとや](https://www.irasutoya.com)

## Installation

Irasutoya requires Ruby 3.3 or later.

Add this line to your application's Gemfile:

```ruby
gem 'irasutoya'
```

Run `bundle install` to install the gem from RubyGems. To install it directly without a Gemfile, run:

```sh
gem install irasutoya
```

## Quick start

Save this example as `find_illustration.rb`:

```ruby
require 'irasutoya'

link = Irasutoya::Irasuto.search(query: 'おじさん').first
if link
  illustration = link.fetch_irasuto
  puts illustration.title
  puts illustration.image_url
else
  puts 'No illustrations found.'
end
```

From the directory where you saved the script, run `bundle exec ruby find_illustration.rb` if you installed with Bundler, or `ruby find_illustration.rb` if you installed with `gem install`. The script searches Irasutoya and prints the title and image URL of the first match.

## Usage

See [Getting started](docs/getting-started.md) for a walkthrough from search results to illustration details.
See the [Ruby API reference](docs/usage.md) for pagination, return values, and fetch behavior.
See [Troubleshooting](docs/troubleshooting.md) for empty results and fetch errors.

Fetch operations raise `Timeout::Error` if they exceed 10 seconds in total. Redirects share this limit, as do all feed and detail requests made by `Irasutoya::Irasuto.random`.
HTML responses are limited to 4 MiB, feed responses to 1 MiB, and image downloads to 10 MiB. Fetch operations raise
`Irasutoya::ResponseTooLargeError` when a response exceeds its limit after decompression.

```ruby
# Irasuto
irasuto = Irasutoya::Irasuto.random #=> returns Irasuto instance
irasuto.url
irasuto.title
irasuto.description
irasuto.image_url
irasuto.image_urls
irasuto.has_multiple_images
irasuto.postthumb_image_url
irasuto.download_image('illustration.png') #=> downloads image_url to disk

irasuto_links = Irasutoya::Irasuto.search(query: 'おじさん', page: 3) #=> returns array of IrasutoLink instance

# Category
categories = Irasutoya::Category.all #=> returns array of Category instance
category = categories.first
category.title
category.list_url

irasuto_links = category.fetch_irasuto_links #=> returns array of IrasutoLink instance

# IrasutoLinks
irasuto_link = irasuto_links.first
irasuto_link.title
irasuto_link.show_url
irasuto_link.thumbnail_url

irasuto = irasuto_link.fetch_irasuto #=> returns Irasuto instance
```

Search and category results expose the thumbnail URL embedded in each listing
card. The URL keeps the size specified in the source and can be used for a
preview without fetching the detail page. Cards without a usable thumbnail
return `nil` from `thumbnail_url`.

### Browse search and category results

```ruby
shortlist = Irasutoya::Irasuto.each_search_result(query: '猫').take(10)

category = Irasutoya::Category.all.find { |entry| entry.title == '猫' }
match = category&.each_irasuto_link&.find { |link| link.title.include?('黒猫') }
```

Both methods return an Enumerator when called without a block. They fetch listing pages
as needed and yield `IrasutoLink` objects. Use `take` or `find` to stop early, and call
`fetch_irasuto` on a chosen link to load its details.

### Open a saved or shared post URL

Pass an absolute post URL on `www.irasutoya.com` to `Irasutoya::Irasuto.from_url`.
The URL can come from a pasted link or a previously selected illustration:

```ruby
saved_url = irasuto.url
reopened = Irasutoya::Irasuto.from_url(saved_url)
puts reopened.title
puts reopened.description
puts reopened.image_url
```

`from_url` raises `ArgumentError` for relative paths, URLs outside the trusted origin,
and pages that load successfully but do not contain an illustration post.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for notable changes in each release.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/irasutoya-tools/irasutoya. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Irasutoya project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/irasutoya-tools/irasutoya/blob/master/CODE_OF_CONDUCT.md).

## Author

[@unhappychoice](https://unhappychoice.com)

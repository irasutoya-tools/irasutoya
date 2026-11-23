# Getting started

Irasutoya is a Ruby gem for finding illustrations on Irasutoya and reading their post details. This walkthrough searches for cats (`猫`), shows up to three matches, and opens the first match.

## Install the gem

Use Ruby 3.3 or later. For a standalone script, install the gem from RubyGems.

```sh
gem install irasutoya
```

If your project uses Bundler, add `gem 'irasutoya'` to its Gemfile and run `bundle install` from the project directory.

## Search and open a match

Save this script as `browse_illustrations.rb`.

```ruby
require 'irasutoya'

query = ARGV.fetch(0, '猫')
matches = Irasutoya::Irasuto.each_search_result(query: query).take(3)

if matches.empty?
  puts 'No illustrations found.'
else
  matches.each do |match|
    puts match.title, match.show_url
    puts "Thumbnail: #{match.thumbnail_url}" if match.thumbnail_url
  end

  illustration = matches.first.fetch_irasuto
  puts "Images for #{illustration.title}:"
  puts illustration.image_urls
end
```

Run `ruby browse_illustrations.rb` after installing with `gem install`, or `bundle exec ruby browse_illustrations.rb` in a Bundler project. The script requests live results from `www.irasutoya.com`. To try another query, pass it as the first argument, for example `ruby browse_illustrations.rb 'おじさん'`.

`take(3)` stops after three matches or when the results end. Each match is an `IrasutoLink` with a post URL and an optional thumbnail URL from the listing. `fetch_irasuto` loads the selected post, where `image_urls` gives the image URLs extracted from the detail page.

Keep a match's `show_url` if you want to open the same post later with `Irasutoya::Irasuto.from_url(saved_url)`.

See the [Ruby API reference](usage.md) for category browsing and fetch behavior, or [Troubleshooting](troubleshooting.md) for empty results and request errors.

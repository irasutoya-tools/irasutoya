# Irasutoya

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

Add this line to your application's Gemfile:

```ruby
gem 'irasutoya'
```

## Quick start

After adding the gem to your Gemfile, run `bundle install`. Save this example as `find_illustration.rb`:

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

Run `bundle exec ruby find_illustration.rb` from your application directory. The script searches Irasutoya and prints the title and image URL of the first match.

## Usage

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

irasuto = irasuto_link.fetch_irasuto #=> returns Irasuto instance
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/irasutoya-tools/irasutoya. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Irasutoya project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/irasutoya-tools/irasutoya/blob/master/CODE_OF_CONDUCT.md).

## Author

[@unhappychoice](https://unhappychoice.com)

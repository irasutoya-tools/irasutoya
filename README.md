# Irasutoya

[![Gem Version](https://badge.fury.io/rb/irasutoya.svg)](https://badge.fury.io/rb/irasutoya)
[![Circle CI](https://circleci.com/gh/unhappychoice/irasutoya.svg?style=shield)](https://circleci.com/gh/unhappychoice/irasutoya)
[![Code Climate](https://codeclimate.com/github/unhappychoice/irasutoya/badges/gpa.svg)](https://codeclimate.com/github/unhappychoice/irasutoya)
[![codecov](https://codecov.io/gh/unhappychoice/irasutoya/branch/master/graph/badge.svg)](https://codecov.io/gh/unhappychoice/irasutoya)
[![Libraries.io dependency status for GitHub repo](https://img.shields.io/librariesio/github/unhappychoice/irasutoya.svg)](https://libraries.io/github/unhappychoice/irasutoya)
![](http://ruby-gem-downloads-badge.herokuapp.com/irasutoya?type=total)
![GitHub](https://img.shields.io/github/license/unhappychoice/irasutoya.svg)

<p align="center">
  <img src="https://1.bp.blogspot.com/-QU1PrEXerMg/XWS5ZxD-tsI/AAAAAAABUR4/1EuTP776BowewKdMAgnAUpUB5m3O7ve-ACLcBGAs/s1600/computer_screen_programming.png" width="400"/>
</p>

`Irasutoya` is ruby library for [いらすとや](https://www.irasutoya.com)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'irasutoya'
```
## Usage

```ruby
# Irasuto
irasuto = Irasutoya::Irasuto.random #=> returns Irasuto instance
irasuto.url
irasuto.title
irasuto.description
irasuto.image_url
irasuto.image_urls
irasuto.has_maltiple_images
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

Bug reports and pull requests are welcome on GitHub at https://github.com/unhappychoice/irasutoya. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Irasutoya project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/unhappychoice/irasutoya/blob/master/CODE_OF_CONDUCT.md).

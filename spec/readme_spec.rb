# frozen_string_literal: true

RSpec.describe 'README usage' do
  it 'reports whether an illustration has multiple images' do
    readme = File.read(File.expand_path('../README.md', __dir__))
    accessor = readme[/^irasuto\.(has_\w+_images)$/, 1]
    expect(accessor).not_to be_nil

    images = %w[https://example.com/first.png https://example.com/second.png]
    single = Irasutoya::Irasuto.new(url: '', title: '', description: '', image_urls: images.take(1))
    multiple = Irasutoya::Irasuto.new(url: '', title: '', description: '', image_urls: images)

    expect(single.public_send(accessor)).to be(false)
    expect(multiple.public_send(accessor)).to be(true)
  end
end

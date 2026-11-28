# frozen_string_literal: true

RSpec.describe 'Getting started walkthrough' do
  let(:guide_path) { File.expand_path('../docs/getting-started.md', __dir__) }
  let(:script) { File.read(guide_path)[/^\`\`\`ruby\n(.*?)^\`\`\`/m, 1] }
  let(:search_api) { double('published Irasuto API') }

  before do
    stub_const('Irasutoya::Irasuto', search_api)
    stub_const('ARGV', [])
  end

  it 'prints up to three search results and opens the first using the published API' do
    illustration = double('illustration', title: 'Cat', image_urls: ['https://example.com/cat.png'])
    first = double('first link', title: 'Cat', show_url: 'https://example.com/cat', fetch_irasuto: illustration)
    other = double('other link', title: 'Kitten', show_url: 'https://example.com/kitten')
    expect(search_api).to receive(:search).with(query: '猫').and_return([first, other, other, double('fourth link')])

    expected = "Cat\nhttps://example.com/cat\n" + "Kitten\nhttps://example.com/kitten\n" * 2 +
               "Images for Cat:\nhttps://example.com/cat.png\n"
    expect { eval(script, binding, guide_path) }.to output(expected).to_stdout
  end

  it 'reports an empty search using the query supplied on the command line' do
    stub_const('ARGV', ['おじさん'])
    expect(search_api).to receive(:search).with(query: 'おじさん').and_return([])

    expect { eval(script, binding, guide_path) }.to output("No illustrations found.\n").to_stdout
  end
end

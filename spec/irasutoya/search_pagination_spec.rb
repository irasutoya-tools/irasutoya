# frozen_string_literal: true

RSpec.describe Irasutoya::Irasuto do
  let(:query) { '猫' }
  let(:search_url) { "https://www.irasutoya.com/search?q=#{CGI.escape(query)}" }
  let(:next_href) { '/search?q=%E7%8C%AB&updated-max=2018-09-01T12:00:00%2B09:00&start=7&by-date=false' }
  let(:next_url) { "https://www.irasutoya.com#{next_href}" }
  let(:first_results) { (1..7).map { |index| "/2018/09/cat-#{index}.html" } }
  let(:next_results) { %w[/2018/09/blog-post_34.html /2018/09/cat-9.html] }

  before do
    first_page = search_document(first_results)
    first_page.at_css('body').add_child(%(<a class="blog-pager-older-link" href="#{CGI.escapeHTML(next_href)}">Next</a>))
    allow(described_class).to receive(:fetch_page_and_parse).with(search_url).and_return(first_page)
    allow(described_class).to receive(:fetch_page_and_parse).with(next_url).and_return(search_document(next_results))
  end

  it 'returns all seven results on the default page without fetching the next page' do
    expect(described_class.search(query: query).map(&:show_url)).to eq(first_results)
    expect(described_class).not_to have_received(:fetch_page_and_parse).with(next_url)
  end

  it 'follows the advertised cursor to the second page' do
    expect(described_class.search(query: query, page: 1).map(&:show_url)).to eq(next_results)
    expect(described_class).to have_received(:fetch_page_and_parse).with(next_url).once
  end

  it 'returns an empty array beyond the last page' do
    expect(described_class.search(query: query, page: 2)).to eq([])
    expect(described_class).to have_received(:fetch_page_and_parse).with(next_url).once
  end

  def search_document(paths)
    results = paths.map do |path|
      %(<div class="box"><a href="#{path}">Image</a><a href="#{path}">Cat</a></div>)
    end
    Nokogiri::HTML("<html><body>#{results.join}</body></html>")
  end
end

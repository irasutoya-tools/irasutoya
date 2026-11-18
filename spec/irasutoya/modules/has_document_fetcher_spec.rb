# frozen_string_literal: true

RSpec.describe Irasutoya::Modules::HasDocumentFetcher do
  let(:page_url) { 'https://www.irasutoya.com/page' }

  def fetch_page(url)
    Irasutoya::IrasutoLink.new(title: 'Irasuto', show_url: url).fetch_page_and_parse(url)
  end

  def redirect_to(location)
    response = Net::HTTPFound.new('1.1', '302', 'Found')
    response['Location'] = location
    allow(response).to receive(:body).and_return('')
    response
  end

  %w[
    https://example.com/page
    https://www.irasutoya.com.example.com/page
    https://www.irasutoya.com@example.com/page
    https://user@www.irasutoya.com/page
    https://www.irasutoya.com:8443/page
    ftp://www.irasutoya.com/page
  ].each do |url|
    it "rejects #{url} before opening a connection" do
      expect(Net::HTTP).not_to receive(:new)

      expect { fetch_page(url) }.to raise_error(ArgumentError, 'Untrusted Irasutoya page URL')
    end
  end

  it 'parses the buffered response directly using the response charset' do
    stub_page('show.html')
    expect(Nokogiri::HTML).to receive(:parse).with(an_instance_of(StringIO), nil, 'utf-8').and_call_original

    expect(fetch_page(page_url)).to be_a(Nokogiri::HTML::Document)
  end

  it 'follows relative redirects and upgrades trusted HTTP redirect targets to HTTPS' do
    http = stub_page('show.html')
    allow(http).to receive(:get).with('/page').and_return(redirect_to('/next'))
    allow(http).to receive(:get).with('/next')
                             .and_return(redirect_to('http://www.irasutoya.com:80/final'))

    expect(fetch_page(page_url)).to be_a(Nokogiri::HTML::Document)
    expect(http).to have_received(:get).with('/final')
    expect(http.use_ssl?).to be(true)
  end

  it 'rejects an off-origin redirect after a trusted redirect' do
    http = stub_page_http
    expect(http).to receive(:get).with('/page').ordered.and_return(redirect_to('/next'))
    expect(http).to receive(:get).with('/next').ordered
                           .and_return(redirect_to('//example.com/page'))

    expect { fetch_page(page_url) }.to raise_error(ArgumentError, 'Untrusted Irasutoya page URL')
  end

  it 'bounds redirect loops' do
    http = stub_page_http
    expect(http).to receive(:get).exactly(11).times.and_return(redirect_to('/page'))

    expect { fetch_page(page_url) }.to raise_error(IOError, 'Too many Irasutoya page redirects')
  end
end

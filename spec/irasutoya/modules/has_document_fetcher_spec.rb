# frozen_string_literal: true

RSpec.describe Irasutoya::Modules::HasDocumentFetcher do
  let(:page_url) { 'https://www.irasutoya.com/page' }

  def fetch_page(url)
    Irasutoya::IrasutoLink.new(title: 'Irasuto', show_url: url).fetch_page_and_parse(url)
  end

  def redirect_to(location)
    response = Net::HTTPFound.new('1.1', '302', 'Found')
    response['Location'] = location
    allow(response).to receive(:read_body)
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

  it 'follows relative redirects and upgrades trusted HTTP redirect targets to HTTPS' do
    http = stub_page('show.html')
    first_redirect = redirect_to('/next')
    final_redirect = redirect_to('http://www.irasutoya.com:80/final')
    allow(http).to receive(:request_get).with('/page').and_yield(first_redirect).and_return(first_redirect)
    allow(http).to receive(:request_get).with('/next').and_yield(final_redirect).and_return(final_redirect)

    expect(fetch_page(page_url)).to be_a(Nokogiri::HTML::Document)
    expect(http).to have_received(:request_get).with('/final')
    expect(http.use_ssl?).to be(true)
  end

  it 'rejects an off-origin redirect after a trusted redirect' do
    http = stub_page_http
    first_redirect = redirect_to('/next')
    final_redirect = redirect_to('//example.com/page')
    expect(http).to receive(:request_get).with('/page').ordered.and_yield(first_redirect).and_return(first_redirect)
    expect(http).to receive(:request_get).with('/next').ordered.and_yield(final_redirect).and_return(final_redirect)

    expect { fetch_page(page_url) }.to raise_error(ArgumentError, 'Untrusted Irasutoya page URL')
  end

  it 'bounds redirect loops' do
    http = stub_page_http
    redirect = redirect_to('/page')
    expect(http).to receive(:request_get).exactly(11).times.and_yield(redirect).and_return(redirect)

    expect { fetch_page(page_url) }.to raise_error(IOError, 'Too many Irasutoya page redirects')
  end
end

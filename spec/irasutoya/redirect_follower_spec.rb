# frozen_string_literal: true

RSpec.describe Irasutoya::RedirectFollower do
  def redirect_to(uri)
    described_class::Redirect.new(uri)
  end

  it 'returns the first non-redirect result without yielding again' do
    calls = []
    result = described_class.follow(:start, 5) do |uri|
      calls << uri
      [:done, uri]
    end

    expect(result).to eq([:done, :start])
    expect(calls).to eq([:start])
  end

  it 'follows a Redirect to the next URI and yields again with it' do
    calls = []
    result = described_class.follow(:start, 5) do |uri|
      calls << uri
      uri == :start ? redirect_to(:next) : [:done, uri]
    end

    expect(result).to eq([:done, :next])
    expect(calls).to eq([:start, :next])
  end

  it 'allows exactly max_redirects redirects before giving up on the final attempt' do
    attempts = 0
    result = described_class.follow(0, 3) do |uri|
      attempts += 1
      uri < 3 ? redirect_to(uri + 1) : [:done, uri]
    end

    expect(result).to eq([:done, 3])
    expect(attempts).to eq(4)
  end

  it 'raises the default message after exceeding max_redirects' do
    expect { described_class.follow(0, 2) { |uri| redirect_to(uri + 1) } }
      .to raise_error(IOError, 'Too many HTTP redirects')
  end

  it 'raises a caller-supplied message after exceeding max_redirects' do
    expect do
      described_class.follow(0, 2, too_many_redirects_message: 'Too many Irasutoya page redirects') do |uri|
        redirect_to(uri + 1)
      end
    end.to raise_error(IOError, 'Too many Irasutoya page redirects')
  end
end

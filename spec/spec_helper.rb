# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.add_filter ['spec']
  SimpleCov.start
end

require 'bundler/setup'
require 'irasutoya'
require_relative 'support/ordered_list_results'

module PageFixtures
  def stub_page(filename)
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    response['Content-Type'] = 'text/html; charset=UTF-8'
    allow(response).to receive(:body).and_return(File.read("spec/files/#{filename}"))
    stub_page_http.tap { |http| allow(http).to receive(:get).and_return(response) }
  end

  def stub_page_http
    http = Net::HTTP.new('www.irasutoya.com', 443, nil)
    allow(http).to receive(:start) do
      allow(http).to receive(:started?).and_return(true)
      http
    end
    allow(http).to receive(:finish)
    allow(Net::HTTP).to receive(:new).with('www.irasutoya.com', 443, any_args).and_return(http)
    http
  end
end

RSpec.configure do |config|
  config.include PageFixtures

  config.before do
    fetcher = Irasutoya::Modules::HasDocumentFetcher
    pool = fetcher.const_get(:HttpSessionPool).new
    stub_const("#{fetcher}::HTTP_DOCUMENT", fetcher.const_get(:HttpDocument).new(pool))
  end

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

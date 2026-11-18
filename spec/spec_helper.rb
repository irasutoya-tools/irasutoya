# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.add_filter ['spec']
  SimpleCov.start
end

require 'bundler/setup'
require 'irasutoya'

module ResponseFixtures
  def stub_html_fixture(filename, url: anything)
    allow(Irasutoya::ResponseFetcher).to receive(:get)
      .with(url, max_bytes: html_byte_limit)
      .and_return([File.binread("spec/files/#{filename}"), 'text/html; charset="UTF-8"'])
  end

  def html_byte_limit
    Irasutoya::Modules::HasDocumentFetcher::MAX_HTML_BYTES
  end
end

RSpec.configure do |config|
  config.include ResponseFixtures

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

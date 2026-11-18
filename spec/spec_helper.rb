# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.add_filter ['spec']
  SimpleCov.start
end

require 'bundler/setup'
require 'irasutoya'
require_relative 'support/ordered_list_results'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

module HttpDocumentFixtures
  def http_document
    Irasutoya::Modules::HasDocumentFetcher.const_get(:HTTP_DOCUMENT)
  end

  def stub_http_document(fixture)
    document = double('HTTP document', charset: 'UTF-8', read: File.read("spec/files/#{fixture}"))
    allow(http_document).to receive(:open).and_yield(document)
  end
end

RSpec.configure { |config| config.include HttpDocumentFixtures }

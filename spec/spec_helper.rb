# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.add_filter ['spec']
  SimpleCov.start
end

require 'bundler/setup'
require 'irasutoya'

module HtmlResponseHelpers
  def stub_html_response(fixture, url: nil)
    uri = url ? URI.parse(url) : anything
    allow(URI).to receive(:parse).and_call_original
    allow(OpenURI).to receive(:open_uri).with(uri) do |&parse|
      File.open(File.join(__dir__, 'files', fixture), 'rb') do |response|
        allow(response).to receive(:charset).and_return('UTF-8')
        allow(response).to receive(:read).and_call_original
        expect(response).not_to receive(:read).with(no_args)
        parse.call(response)
      end
    end
  end
end

RSpec.configure do |config|
  config.include HtmlResponseHelpers

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

# frozen_string_literal: true

module Irasutoya
  class ResponseTooLargeError < StandardError; end

  module ResponseFetcher
    REDIRECT_CODES = %w[301 302 303 307 308].freeze
    MAX_REDIRECTS = 64

    def self.get(url, max_bytes:)
      uri = URI.parse(url)
      raise ArgumentError, 'Expected an HTTP or HTTPS URL' unless uri.is_a?(URI::HTTP)

      (MAX_REDIRECTS + 1).times do
        result = request(uri, max_bytes)
        return result if result.is_a?(Array)

        uri = redirect_uri(uri, result)
      end
      raise IOError, 'Too many HTTP redirects'
    end

    def self.request(uri, max_bytes)
      host = uri.hostname || raise(ArgumentError, 'Expected an HTTP or HTTPS host')

      Net::HTTP.start(host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        body = ''.b
        response = http.request_get(uri.request_uri) do |response|
          return response.fetch('location') if REDIRECT_CODES.include?(response.code)

          response.value
          body = read_body(http, response, max_bytes)
        end
        [body, response['content-type']]
      end
    end
    private_class_method :request

    def self.redirect_uri(uri, location)
      target = uri + location
      return target if target.is_a?(URI::HTTP) && (uri.scheme == 'http' || target.scheme == 'https')

      raise IOError, "HTTP redirect to unsupported scheme: #{target.scheme}"
    end
    private_class_method :redirect_uri

    def self.read_body(http, response, max_bytes)
      body = ''.b
      response.read_body do |chunk|
        abort_download(http, max_bytes) if body.bytesize + chunk.bytesize > max_bytes

        body << chunk
      end
      body
    rescue IOError => e
      # Net::HTTP can try to read the chunk terminator while unwinding.
      cause = e.cause
      raise cause if cause.is_a?(ResponseTooLargeError)

      raise
    end
    private_class_method :read_body

    def self.abort_download(http, max_bytes)
      http.finish
      raise ResponseTooLargeError, "HTTP response exceeds the #{max_bytes}-byte limit"
    end
    private_class_method :abort_download
  end
end

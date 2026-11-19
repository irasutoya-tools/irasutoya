# frozen_string_literal: true

module Irasutoya
  class ResponseTooLargeError < StandardError; end

  module ResponseFetcher
    REDIRECT_CODES = %w[301 302 303 307 308].freeze
    MAX_REDIRECTS = 64

    def self.get(url, max_bytes:, follow_redirects: true)
      uri = URI.parse(url)
      raise ArgumentError, 'Expected an HTTP or HTTPS URL' unless uri.is_a?(URI::HTTP)

      (MAX_REDIRECTS + 1).times do
        result = request(uri, max_bytes, follow_redirects)
        return result if result.is_a?(Array)

        uri = redirect_uri(uri, result)
      end
      raise IOError, 'Too many HTTP redirects'
    end

    def self.read_body(http, response, max_bytes)
      HTTP_TRANSPORT.read_body(http, response, max_bytes)
    end

    def self.request(uri, max_bytes, follow_redirects)
      body = ''.b
      response = HTTP_TRANSPORT.request(uri) do |http, reply|
        return reply.fetch('location') if follow_redirects && REDIRECT_CODES.include?(reply.code)

        reply.value
        body = read_body(http, reply, max_bytes)
      end
      [body, response['content-type']]
    end
    private_class_method :request

    def self.redirect_uri(uri, location)
      target = uri + location
      return target if target.is_a?(URI::HTTP) && (uri.scheme == 'http' || target.scheme == 'https')

      raise IOError, "HTTP redirect to unsupported scheme: #{target.scheme}"
    end
    private_class_method :redirect_uri
  end
end

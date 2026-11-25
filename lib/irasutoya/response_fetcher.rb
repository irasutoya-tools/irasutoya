# frozen_string_literal: true

module Irasutoya
  class ResponseTooLargeError < StandardError; end

  module ResponseFetcher
    MAX_REDIRECTS = 64

    def self.get(url, max_bytes:, follow_redirects: true)
      uri = URI.parse(url)
      raise ArgumentError, 'Expected an HTTP or HTTPS URL' unless uri.is_a?(URI::HTTP)

      RedirectFollower.follow(uri, MAX_REDIRECTS) do |current|
        result = request(current, max_bytes, follow_redirects)
        result.is_a?(Array) ? result : RedirectFollower::Redirect.new(redirect_uri(current, result))
      end
    end

    def self.read_body(http, response, max_bytes)
      HTTP_TRANSPORT.read_body(http, response, max_bytes)
    end

    def self.request(uri, max_bytes, follow_redirects)
      body = ''.b
      response = HTTP_TRANSPORT.request(uri) do |http, reply|
        return reply.fetch('location') if follow_redirects && RedirectFollower::REDIRECT_CODES.include?(reply.code)

        reply.value
        body = read_body(http, reply, max_bytes)
      end
      [body, response['content-type']]
    end
    private_class_method :request

    # Allows any HTTP(S) host but rejects an https -> http scheme downgrade. HttpDocument applies
    # a stricter, trusted-host-only policy instead; see Modules::HasDocumentFetcher::HttpDocument.
    def self.redirect_uri(uri, location)
      target = uri + location
      return target if target.is_a?(URI::HTTP) && (uri.scheme == 'http' || target.scheme == 'https')

      raise IOError, "HTTP redirect to unsupported scheme: #{target.scheme}"
    end
    private_class_method :redirect_uri
  end
end

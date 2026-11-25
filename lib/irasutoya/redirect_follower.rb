# frozen_string_literal: true

module Irasutoya
  # Shared hop-capped loop for following HTTP redirects. ResponseFetcher and HttpDocument each run
  # their own request and resolve a Location header under their own trust policy: ResponseFetcher
  # only rejects an https -> http scheme downgrade, while HttpDocument also restricts the target to
  # a single trusted host. A block yields a Redirect to continue the loop at a new URI, or returns
  # any other value to stop and hand it back as the result.
  module RedirectFollower
    REDIRECT_CODES = %w[301 302 303 307 308].freeze

    class Redirect
      attr_reader :uri

      def initialize(uri)
        @uri = uri
      end
    end

    def self.follow(uri, max_redirects, too_many_redirects_message: 'Too many HTTP redirects')
      (max_redirects + 1).times do
        case result = yield uri
        when Redirect
          uri = result.uri
        else
          return result
        end
      end
      raise IOError, too_many_redirects_message
    end
  end
end

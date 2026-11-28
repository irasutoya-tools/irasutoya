# frozen_string_literal: true

module Irasutoya
  # A waiter that times out does not cancel the in-flight refresh; a refresh that times out
  # just lets the next caller start a replacement.
  class FeedCountCache
    FeedCountRefresh = Struct.new(:pid, :result, :error)
    private_constant :FeedCountRefresh

    def initialize(ttl:, &fetch)
      @ttl = ttl
      @fetch = fetch
      @lock = Mutex.new
      @ready = ConditionVariable.new
    end

    def fetch(stale_count: nil, fetch: @fetch)
      # Keep registration and cleanup atomic with respect to the fetch deadline.
      with_count_interrupt(:never) do
        pending = @lock.synchronize do
          result = cached_or_shared_result(stale_count)
          return result if result

          @refresh = FeedCountRefresh.new(Process.pid)
        end
        refresh_count(pending, fetch)
      end
    end

    private

    def cached_count
      count, expires_at = @cache
      count if expires_at && clock_time < expires_at
    end

    def cached_or_shared_result(stale_count)
      loop do
        count = cached_count
        return [count, nil] if count && count != stale_count

        current = @refresh
        return unless current && current.pid == Process.pid

        result = wait_for_refresh(current)
        return result if result
      end
    end

    def wait_for_refresh(refresh)
      with_count_interrupt(:immediate) do
        @ready.wait(@lock) while @refresh.equal?(refresh)
      end
      error = refresh.error
      return if error.is_a?(FetchDeadlineExceeded)

      raise error if error

      refresh.result || raise(IOError, 'Feed count refresh interrupted')
    end

    def refresh_count(refresh, fetch)
      result = with_count_interrupt(:immediate) { fetch_and_cache(fetch) }
      refresh.result = result
    rescue StandardError => e
      refresh.error = e
      raise
    ensure
      finish_refresh
    end

    def finish_refresh
      @lock.synchronize do
        @refresh = nil
        @ready.broadcast
      end
    end

    def fetch_and_cache(fetch)
      count, feed = fetch.call
      @cache = count.positive? ? [count, clock_time + @ttl] : nil
      [count, feed]
    end

    def with_count_interrupt(timing, &)
      # @type var thread: untyped
      thread = Thread
      thread.handle_interrupt(FetchDeadlineExceeded => timing, &)
    end

    def clock_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end

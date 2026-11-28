# frozen_string_literal: true

RSpec.describe Irasutoya::FeedCountCache do
  let(:deadline) { Irasutoya.const_get(:FetchDeadlineExceeded) }
  let(:requests) { Queue.new }
  let(:release) { Queue.new }

  def new_cache(ttl: 300)
    described_class.new(ttl: ttl) do
      requests << true
      outcome = release.pop
      raise outcome if outcome.is_a?(Exception)

      outcome
    end
  end

  def start_worker(cache, stale_count: nil)
    Thread.new do
      cache.fetch(stale_count: stale_count)
    rescue StandardError => e
      e
    end
  end

  def start_waiter(cache, stale_count: nil)
    start_worker(cache, stale_count: stale_count).tap do |worker|
      Timeout.timeout(3) { Thread.pass until worker.status == 'sleep' }
    end
  end

  def pop(queue)
    Timeout.timeout(3) { queue.pop }
  end

  def result(worker)
    expect(worker.join(3)).to be(worker)
    worker.value
  end

  it 'caches a positive count until a stale caller forces a refresh' do
    cache = described_class.new(ttl: 300) { [2, { 'entry' => ['first'] }] }

    expect(cache.fetch(stale_count: nil)).to eq([2, { 'entry' => ['first'] }])
    expect(cache.fetch(stale_count: nil)).to eq([2, nil])
    expect(cache.fetch(stale_count: 2)).to eq([2, { 'entry' => ['first'] }])
  end

  it 'does not cache a non-positive count' do
    calls = 0
    cache = described_class.new(ttl: 300) do
      calls += 1
      [0, {}]
    end

    cache.fetch(stale_count: nil)
    cache.fetch(stale_count: nil)

    expect(calls).to eq(2)
  end

  it 'expires the cache once the ttl elapses' do
    cache = described_class.new(ttl: 10) { [2, {}] }
    allow(cache).to receive(:clock_time).and_return(100.0)

    cache.fetch(stale_count: nil)

    allow(cache).to receive(:clock_time).and_return(111.0)
    expect(cache.fetch(stale_count: nil)).to eq([2, {}])
  end

  it 'coalesces concurrent refreshes and shares the exact result with waiters' do
    cache = new_cache

    leader = start_worker(cache)
    pop(requests)
    followers = Array.new(3) { start_waiter(cache) }
    release << [3, { 'entry' => ['shared'] }]

    expect([leader, *followers].map { |worker| result(worker) }).to eq([[3, { 'entry' => ['shared'] }]] * 4)
    expect(requests.size).to eq(0)
  end

  it 'serves a valid cache hit while a forced refresh is blocked and later fails' do
    cache = new_cache
    release << [10, {}]
    cache.fetch
    pop(requests)

    leader = start_worker(cache, stale_count: 10)
    pop(requests)
    follower = start_waiter(cache, stale_count: 10)
    reader = start_worker(cache)
    expect(result(reader)).to eq([10, nil])

    error = IOError.new('Count request failed')
    release << error
    expect([result(leader), result(follower)]).to eq([error, error])
    expect(cache.fetch).to eq([10, nil])
    expect(requests.size).to eq(0)
  ensure
    [leader, follower, reader].compact.each { |worker| worker.kill.join }
  end

  it 'lets waiters start one replacement when the initiating refresh deadline expires' do
    cache = new_cache

    leader = Thread.new do
      Timeout.timeout(0.1, deadline) { cache.fetch(stale_count: nil) }
    rescue StandardError => e
      e
    end
    pop(requests)
    followers = Array.new(3) { start_waiter(cache) }

    expect(result(leader)).to be_a(deadline)
    pop(requests)
    release << [8, {}]

    expect(followers.map { |worker| result(worker) }).to eq([[8, {}]] * 3)
  end

  it 'shares a refresh error with waiters and lets a later call retry' do
    cache = new_cache

    leader = start_worker(cache)
    pop(requests)
    waiter = start_waiter(cache)
    release << IOError.new('Count request failed')

    [leader, waiter].each { |worker| expect(result(worker)).to be_a(IOError) }

    retry_worker = start_worker(cache)
    pop(requests)
    release << [5, {}]
    expect(result(retry_worker)).to eq([5, {}])
  end

  it 'allows a later refresh when the fetch exceeds its deadline' do
    cache = new_cache

    leader = Thread.new do
      Timeout.timeout(0.1, deadline) { cache.fetch(stale_count: nil) }
    rescue StandardError => e
      e
    end
    pop(requests)
    expect(result(leader)).to be_a(deadline)

    release << [6, {}]
    retry_worker = start_worker(cache)
    expect(result(retry_worker)).to eq([6, {}])
  end

  it 'lets a waiting caller reach its own deadline without cancelling the refresh' do
    cache = new_cache

    leader = start_worker(cache)
    pop(requests)
    waiter = Thread.new do
      Timeout.timeout(0.1, deadline) { cache.fetch(stale_count: nil) }
    rescue StandardError => e
      e
    end
    expect(result(waiter)).to be_a(deadline)

    release << [7, {}]
    expect(result(leader)).to eq([7, {}])
  end
end

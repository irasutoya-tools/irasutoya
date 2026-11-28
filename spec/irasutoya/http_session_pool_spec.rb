# frozen_string_literal: true

RSpec.describe 'HTTP session pool waiters' do
  let(:pool) { Irasutoya.const_get(:HttpSessionPool).new(max_connections: 1) }
  let(:deadline) { Irasutoya.const_get(:FetchDeadlineExceeded) }
  let(:origin) { [Process.pid, 'https', 'example.com', 443, nil] }
  let(:proxy_origin) { [*origin.take(4), 'http://proxy.example.com'] }
  let(:workers) { [] }
  let(:waiting) { Queue.new }
  let(:waiters) { pool.instance_variable_get(:@waiters) }

  before do
    allow(waiters).to receive(:wait).and_wrap_original do |wait, key, lock|
      waiting << key
      wait.call(key, lock)
    end
  end

  after { workers.each { |worker| worker.kill.join } }

  it 'signals only one waiter for each released session on the same pool key' do
    _, held, release = start_request(origin)
    _, proxy_held, proxy_release = start_request(proxy_origin)
    expect(held.pop(timeout: 2)).to eq(:acquired)
    expect(proxy_held.pop(timeout: 2)).to eq(:acquired)

    (_, first, finish_first), first_waiter = queue_request(origin)
    (_, second, _), second_waiter = queue_request(origin)
    (_, proxy, _), proxy_waiter = queue_request(proxy_origin)

    release << true
    expect(first.pop(timeout: 2)).to eq(:acquired)
    expect(first_waiter).to have_received(:signal).once
    [second_waiter, proxy_waiter].each do |waiter|
      expect(waiter).not_to have_received(:signal)
      expect(waiter).not_to have_received(:broadcast)
    end

    finish_first << true
    proxy_release << true
    expect(second.pop(timeout: 2)).to eq(:acquired)
    expect(proxy.pop(timeout: 2)).to eq(:acquired)
  end

  it 'passes the notification on if the selected waiter reaches its fetch deadline' do
    _, held, release = start_request(origin)
    expect(held.pop(timeout: 2)).to eq(:acquired)
    (expiring, result, _), selected = queue_request(origin)
    (_, remaining, _), = queue_request(origin)

    # Deliver the deadline while the release still holds the pool lock.
    allow(selected).to receive(:signal).and_wrap_original do |signal|
      expiring.raise(deadline)
      signal.call
    end

    release << true
    expect(result.pop(timeout: 2)).to eq(:expired)
    expect(remaining.pop(timeout: 2)).to eq(:acquired)
  end

  def start_request(key)
    result = Queue.new
    release = Queue.new
    worker = Thread.new do
      pool.send(:with_session, key) do
        result << :acquired
        release.pop
      end
    rescue deadline
      result << :expired
    end
    workers << worker
    [worker, result, release]
  end

  def queue_request(key)
    request = start_request(key)
    expect(waiting.pop(timeout: 2)).to eq(key)
    lock = pool.instance_variable_get(:@lock)
    waiter = lock.synchronize { waiters.instance_variable_get(:@queues).fetch(key).keys.last }
    allow(waiter).to receive(:signal).and_call_original
    allow(waiter).to receive(:broadcast).and_call_original
    [request, waiter]
  end
end

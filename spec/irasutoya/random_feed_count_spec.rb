# frozen_string_literal: true

RSpec.describe Irasutoya::Irasuto, 'concurrent random feed counts' do
  let(:show_url) { 'https://www.irasutoya.com/2014/03/blog-post_5924.html' }
  let(:feed) do
    JSON.generate(feed: {
                    'openSearch$totalResults' => { '$t' => '2' },
                    'entry' => [{ link: [{ rel: 'alternate', href: show_url }] }]
                  })
  end
  let(:count_url) { /start-index=1&/ }
  let(:selected_url) { /start-index=2&/ }

  before do
    @workers = []
    @count_requests = Queue.new
    @release_count = Queue.new
    allow(Random).to receive(:rand).with(2).and_return(1)
    allow(Irasutoya::ResponseFetcher).to receive(:get).with(selected_url, any_args).and_return([feed, nil])
    document = Nokogiri::HTML(File.read('spec/files/show.html'))
    allow(described_class).to receive(:fetch_page_and_parse).with(show_url).and_return(document)
  end

  after do
    @workers.each(&:kill)
    @workers.each(&:join)
  end

  shared_examples 'a shared count refresh' do
    it 'refreshes once and lets four callers fetch their selections and details independently' do
      selected_requests = Queue.new
      release_selected = Queue.new
      detail_requests = Queue.new
      release_details = Queue.new
      document = Nokogiri::HTML(File.read('spec/files/show.html'))

      block_count_request { [feed, nil] }
      expect(Irasutoya::ResponseFetcher).to receive(:get).with(selected_url, any_args).exactly(4).times do
        selected_requests << true
        release_selected.pop
        [feed, nil]
      end
      expect(described_class).to receive(:fetch_page_and_parse).with(show_url).exactly(4).times do
        detail_requests << true
        release_details.pop
        document
      end

      leader = start_refresh
      followers = Array.new(3) { start_waiter }
      @release_count << true

      4.times { pop(selected_requests) }
      4.times { release_selected << true }
      4.times { pop(detail_requests) }
      4.times { release_details << true }
      expect([leader, *followers].map { |worker| result(worker).url }).to eq([show_url] * 4)
      expect(@count_requests).to be_empty
    end
  end

  context 'with a cold cache' do
    include_examples 'a shared count refresh'
  end

  context 'with an expired cache' do
    before do
      allow(described_class).to receive(:feed_count_time).and_return(100.0)
      allow(Irasutoya::ResponseFetcher).to receive(:get).with(count_url, any_args).and_return([feed, nil])
      described_class.random
      allow(described_class).to receive(:feed_count_time).and_return(400.0)
    end

    include_examples 'a shared count refresh'
  end

  it 'refreshes once and lets retries reuse the refreshed count instead of repeating the refresh' do
    stale_count = 10
    refreshed_count = 4
    stale_feed = JSON.generate(feed: { 'openSearch$totalResults' => { '$t' => stale_count.to_s } })
    refreshed_feed = JSON.generate(
      feed: {
        'openSearch$totalResults' => { '$t' => refreshed_count.to_s },
        'entry' => [{ link: [{ rel: 'alternate', href: show_url }] }]
      }
    )
    described_class.instance_variable_set(:@feed_count_cache, [stale_count, Float::INFINITY])

    stale_requests = Queue.new
    release_stale = Queue.new
    count_requests = Queue.new
    release_count = Queue.new
    finished = Queue.new

    allow(Random).to receive(:rand).with(stale_count).and_return(stale_count - 1)
    allow(Random).to receive(:rand).with(refreshed_count).and_return(0, 1, 2, 3)
    allow(Irasutoya::ResponseFetcher).to receive(:get).with(/start-index=#{stale_count}&/, any_args) do
      stale_requests << true
      release_stale.pop
      [stale_feed, nil]
    end
    allow(Irasutoya::ResponseFetcher).to receive(:get).with(count_url, any_args) do
      count_requests << true
      release_count.pop
      [refreshed_feed, nil]
    end
    [2, 3, 4].each do |index|
      allow(Irasutoya::ResponseFetcher).to receive(:get).with(/start-index=#{index}&/, any_args) do
        [refreshed_feed, nil]
      end
    end

    @workers = Array.new(4) do
      Thread.new do
        described_class.random
      rescue StandardError => e
        e
      ensure
        finished << true
      end
    end

    4.times { pop(stale_requests) }

    release_stale << true
    pop(count_requests)
    release_count << true
    pop(finished)

    3.times do
      release_stale << true
      pop(finished)
    end

    expect(@workers.map { |worker| result(worker).url }).to eq([show_url] * 4)
    expect(count_requests).to be_empty
  end

  it 'shares the refresh error and allows a subsequent call to retry' do
    block_count_request { raise IOError, 'Count request failed' }
    leader = start_refresh
    waiter = start_waiter
    @release_count << true

    [leader, waiter].each { |worker| expect(result(worker)).to be_a(IOError) }
    expect(@count_requests).to be_empty
    allow(Irasutoya::ResponseFetcher).to receive(:get).with(count_url, any_args).and_return([feed, nil])
    expect(described_class.random.url).to eq(show_url)
  end

  it 'allows a later refresh when the count request exceeds its deadline' do
    stub_const('Irasutoya::Modules::HasDocumentFetcher::FETCH_TIMEOUT', 0.1)
    block_count_request { [feed, nil] }

    expect(result(start_refresh)).to be_a(Timeout::Error)
    allow(Irasutoya::ResponseFetcher).to receive(:get).with(count_url, any_args).and_return([feed, nil])
    expect(described_class.random.url).to eq(show_url)
  end

  it 'lets current waiters share one replacement when the initiating deadline expires' do
    deadline = Irasutoya.const_get(:FetchDeadlineExceeded)
    block_count_request do |error|
      raise error if error

      [feed, nil]
    end
    leader = start_refresh
    followers = Array.new(3) { start_waiter }

    @release_count << deadline.new('execution expired')
    expect(result(leader)).to be_a(Timeout::Error)
    pop(@count_requests)

    stub_const('Irasutoya::Modules::HasDocumentFetcher::FETCH_TIMEOUT', 0.1)
    expect(result(start_worker)).to be_a(Timeout::Error)

    @release_count << nil
    expect(followers.map { |worker| result(worker).url }).to eq([show_url] * 3)
    expect(@count_requests).to be_empty
  end

  it 'lets a waiting caller reach its own deadline without cancelling the refresh' do
    block_count_request { [feed, nil] }
    leader = start_refresh
    stub_const('Irasutoya::Modules::HasDocumentFetcher::FETCH_TIMEOUT', 0.1)

    expect(result(start_worker)).to be_a(Timeout::Error)
    expect(@count_requests).to be_empty
    @release_count << true
    expect(result(leader).url).to eq(show_url)
    expect(described_class.random.url).to eq(show_url)
  end

  def block_count_request
    allow(Irasutoya::ResponseFetcher).to receive(:get).with(count_url, any_args) do
      @count_requests << true
      yield @release_count.pop
    end
  end

  def start_worker
    Thread.new do
      described_class.random
    rescue StandardError => e
      e
    end.tap { |worker| @workers << worker }
  end

  def start_refresh
    start_worker.tap { pop(@count_requests) }
  end

  def start_waiter
    start_worker.tap do |worker|
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
end

# frozen_string_literal: true

require 'open3'

RSpec.describe 'Steep library target' do
  it 'type-checks the library with its dependency signatures' do
    project = File.expand_path('..', __dir__)
    output, status = Open3.capture2e('bundle', 'exec', 'steep', 'check', '--jobs=2', chdir: project)

    expect(status.success?).to be(true), output
  end
end

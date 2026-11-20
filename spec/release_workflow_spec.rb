# frozen_string_literal: true

require 'yaml'

RSpec.describe 'Release workflow' do
  it 'uses the repository Ruby version and tests it in CI' do
    root = File.expand_path('..', __dir__)
    ruby_version = File.read(File.join(root, '.ruby-version')).strip
    release = YAML.safe_load_file(File.join(root, '.github/workflows/release.yaml'))
    ci = YAML.safe_load_file(File.join(root, '.github/workflows/test.yml'))
    setup = release.fetch('jobs').fetch('push').fetch('steps').find { |step| step['uses']&.start_with?('ruby/setup-ruby@') }
    tested_versions = ci.dig('jobs', 'test', 'strategy', 'matrix', 'ruby')

    expect(setup.dig('with', 'ruby-version')).to eq('.ruby-version')
    expect(tested_versions).to include(ruby_version)
  end

  it 'pins every action and reusable workflow to a full commit SHA' do
    workflow = YAML.safe_load_file(File.expand_path('../.github/workflows/release.yaml', __dir__))
    jobs = workflow.fetch('jobs').values
    references = jobs.flat_map { |job| [job, *job.fetch('steps', [])] }.filter_map { |entry| entry['uses'] }

    expect(references).not_to be_empty
    expect(references).to all(match(/@\h{40}\z/))
  end
end

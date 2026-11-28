# frozen_string_literal: true

require 'open3'
require 'yaml'

RSpec.describe 'Release workflow' do
  let(:project) { File.expand_path('..', __dir__) }
  let(:workflow) { YAML.safe_load_file(File.join(project, '.github/workflows/release.yaml')) }

  it 'runs on version tag pushes' do
    expect(workflow.fetch('on')).to eq('push' => { 'tags' => ['v*'] })
  end

  it 'accepts the gem version and rejects mismatched or malformed tags before publishing' do
    steps = workflow.dig('jobs', 'push', 'steps')
    check = steps.find { |step| step['name'] == 'Verify release tag' }
    publish = steps.find { |step| step['uses']&.start_with?('rubygems/release-gem@') }

    expect(steps.index(check)).to be < steps.index(publish)
    version = Gem::Specification.load(File.join(project, 'irasutoya.gemspec')).version
    expect(run_tag_check(check, "v#{version}")).to be_success
    different_version = "v#{version.segments.first + 1}.0.0"
    ["v#{version}.1", "v#{version}.pre", different_version].each do |tag|
      expect(run_tag_check(check, tag)).not_to be_success
    end
  end

  it 'uses the repository Ruby version and tests it in CI' do
    ruby_version = File.read(File.join(project, '.ruby-version')).strip
    ci = YAML.safe_load_file(File.join(project, '.github/workflows/test.yml'))
    steps = workflow.fetch('jobs').fetch('push').fetch('steps')
    setup = steps.find { |step| step['uses']&.start_with?('ruby/setup-ruby@') }
    tested_versions = ci.dig('jobs', 'test', 'strategy', 'matrix', 'ruby')

    expect(setup.dig('with', 'ruby-version')).to eq('.ruby-version')
    expect(tested_versions).to include(ruby_version)
  end

  it 'pins every action and reusable workflow to a full commit SHA' do
    jobs = workflow.fetch('jobs').values
    references = jobs.flat_map { |job| [job, *job.fetch('steps', [])] }.filter_map { |entry| entry['uses'] }

    expect(references).not_to be_empty
    expect(references).to all(match(/@\h{40}\z/))
  end

  def run_tag_check(step, tag)
    Open3.capture2e({ 'GITHUB_REF_NAME' => tag }, 'bash', '-e', '-c', step.fetch('run'), chdir: project).last
  end
end

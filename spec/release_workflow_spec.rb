# frozen_string_literal: true

require 'yaml'

RSpec.describe 'Release workflow' do
  it 'pins every action and reusable workflow to a full commit SHA' do
    workflow = YAML.safe_load_file(File.expand_path('../.github/workflows/release.yaml', __dir__))
    jobs = workflow.fetch('jobs').values
    references = jobs.flat_map { |job| [job, *job.fetch('steps', [])] }.filter_map { |entry| entry['uses'] }

    expect(references).not_to be_empty
    expect(references).to all(match(/@\h{40}\z/))
  end
end

# frozen_string_literal: true

require 'open3'
require 'tmpdir'

RSpec.describe 'Release version bump' do
  {
    'major' => ->(major, _minor, _patch) { [major + 1, 0, 0] },
    'minor' => ->(major, minor, _patch) { [major, minor + 1, 0] },
    'patch' => ->(major, minor, patch) { [major, minor, patch + 1] }
  }.each do |level, next_version|
    it "bumps the #{level} version through the locked bundle" do
      project = File.expand_path('..', __dir__)
      Dir.mktmpdir('irasutoya-release') do |checkout|
        run_command('git', 'clone', '--quiet', '--shared', project, checkout)
        version_file = File.join(checkout, 'lib/irasutoya/version.rb')
        version = File.read(version_file)[/VERSION = '([^']+)'/, 1]
        expected = next_version.call(*version.split('.').map(&:to_i)).join('.')

        run_command({ 'BUNDLE_FROZEN' => 'true', 'BUNDLE_GEMFILE' => File.join(project, 'Gemfile') },
                    'bundle', 'exec', 'ruby', '-rrubygems/command', '-rgem/release', '-rrubygems/commands/bump_command',
                    '-e', 'Gem::Commands::BumpCommand.new.invoke(*ARGV)', '--',
                    '--version', level, '--no-commit', chdir: checkout)

        expect(File.read(version_file)).to include("VERSION = '#{expected}'")
      end
    end
  end

  def run_command(*args, **options)
    output, status = Open3.capture2e(*args, **options)
    expect(status.success?).to be(true), output
  end
end

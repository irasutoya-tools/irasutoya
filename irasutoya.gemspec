# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'irasutoya/version'

Gem::Specification.new do |spec|
  spec.name          = 'irasutoya'
  spec.version       = Irasutoya::VERSION
  spec.required_ruby_version = '>= 2.4'
  spec.authors       = ['Yuji Ueki']
  spec.email         = ['unhappychoice@gmail.com']

  spec.summary       = 'CLI and library for irastoya'
  spec.description   = 'CLI and library for irastoya'
  spec.homepage      = 'https://github.com/unhappychoice/irasutoya'
  spec.license       = 'MIT'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/unhappychoice/irasutoya'
  spec.metadata['changelog_uri'] = 'https://github.com/unhappychoice/irasutoya'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'nokogiri'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'codecov'
  spec.add_development_dependency 'guard'
  spec.add_development_dependency 'guard-rspec'
  spec.add_development_dependency 'guard-rubocop'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rbs'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'steep'
end

# Contributing

Bug reports and pull requests are welcome. Please follow the [Code of Conduct](CODE_OF_CONDUCT.md) when participating.

See the [architecture guide](docs/architecture.md) for where to start reading the code and specs.

## Set up your development environment

Fork the repository on GitHub and clone your fork. Use the Ruby version in [`.ruby-version`](.ruby-version), then install the Bundler version listed under `BUNDLED WITH` in [`Gemfile.lock`](Gemfile.lock) if needed. From the repository root, install the development dependencies.

```sh
bundle install --jobs 4
```

## Run the checks

Run the same tests, lint, and formatting checks used by [CI](.github/workflows/test.yml).

```sh
bundle exec rspec
bundle exec rubocop lib
bundle exec rubocop --only Layout
gem build irasutoya.gemspec
```

Run `bundle exec rubocop --fix-layout` to apply Ruby formatting corrections.

The scraping specs use saved HTML and feed responses in [`spec/files/`](spec/files/). When changing a parser, update or add a fixture and a spec if needed to cover the behavior.

## Open a pull request

1. Create a branch from the upstream `master` branch.
2. Make a focused change and run the checks above.
3. Commit with a Conventional Commit subject, such as `docs: clarify installation`.
4. Push your branch to your fork and open a pull request against `irasutoya-tools/irasutoya:master`. Describe what changed, why, and which checks you ran. Link a related issue if there is one.

## Release a new version

Update `lib/irasutoya/version.rb` and `CHANGELOG.md`, then run `bundle lock` to update the version in `Gemfile.lock`. Submit those changes in a pull request.

Once the release commit is on `master` and CI has passed, push a matching tag in the form `vMAJOR.MINOR.PATCH` to the upstream repository. The [release workflow](.github/workflows/release.yaml) validates the tag against the gem version, builds the gem, and publishes it to RubyGems.org.

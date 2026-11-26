# Changelog

All notable changes to this project are documented in this file. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Releases are tagged at
https://github.com/irasutoya-tools/irasutoya/tags.

## [2.0.4] - 2026-11-14

### Changed

- Raised the minimum supported Ruby version to 3.3 (dropped Ruby 3.2 support).

### Fixed

- Replaced the deprecated `codecov` gem with the official `codecov/codecov-action` GitHub Action,
  fixing broken coverage uploads in CI.

### Added

- Added an Author section with a website link to the README.

## [2.0.3] - 2026-02-03

### Fixed

- `description_from` now handles both the old (two `.separator` elements) and new (one
  `.separator` element) いらすとや page layouts, fixing description parsing on newer posts.

## [2.0.2] - 2025-06-21

### Fixed

- Fixed `Irasutoya::Irasuto.random`, which was broken because it requested the random feed path
  without an absolute URI.

## [2.0.1] - 2025-06-21

No user-facing changes.

## [2.0.0] - 2025-06-21

### Changed

- **Breaking:** dropped support for Ruby 2.x; Ruby 3.0 or later is now required.
- Replaced CircleCI with GitHub Actions for CI, added RuboCop linting, and automated gem releases
  through a GitHub Actions workflow.

## [1.1.0] - 2020-10-16

### Added

- Added RBS type signatures and Steep static type checking for the library.

## [1.0.0] - 2019-09-14

### Added

- Added `Irasutoya::Category` and `Irasutoya::IrasutoLink`, with support for listing categories
  and searching illustrations via `Irasutoya::Irasuto.search`.

### Changed

- **Breaking:** renamed `Irasutoya.random` to `Irasutoya::Irasuto.random`.
- **Breaking:** renamed `Category#name` to `Category#title`.

## [0.1.0] - 2019-09-14

- Initial release: fetch a random illustration from いらすとや via `Irasutoya::Irasuto.random`.

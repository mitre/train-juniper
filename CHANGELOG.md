# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.7.4] - 2025-06-24

### Added

- Add Windows plink.exe support for bastion authentication

### Documentation

- Add Windows bastion setup guide and improve navigation
- Fix MkDocs link warnings
- Add host key acceptance instructions and InSpec testing examples
- Improve Windows documentation and standardize on inspec shell

### Miscellaneous Tasks

- Fix linting issues in Windows test script

### Testing

- Add Windows testing scripts and guide
- Add .env file support to Windows test scripts

## [0.7.3] - 2025-06-23

### Documentation

- Improve README structure for better MkDocs rendering
- Add platform support section to README

### Fixed

- Follow standard RubyGems conventions for gem packaging
- Remove .md extensions from internal MkDocs links
- **docs**: Improve Support section formatting with subsections
- **windows**: Use PowerShell for SSH_ASKPASS on Windows and add cross-platform CI/CD
- **ci**: Add comprehensive platform support for cross-platform compatibility
- Update ffi dependency to support Ruby 3.3 on Windows
- Handle Windows PowerShell script paths in bastion proxy tests
- Use direct gem push instead of rubygems/release-gem action
- Complete release workflow implementation

### Miscellaneous Tasks

- Add session.md to .gitignore

### Styling

- Fix trailing whitespace in bastion proxy files

### Testing

- Add nocov markers for Windows-specific PowerShell code

## [0.7.1] - 2025-06-23

### Added

- Implement Priority 2 DRY improvements and boost coverage to 90.88%
- Add coverage analysis utility script
- Boost test coverage to 93.13% and enhance coverage analysis tool
- **coverage**: Integrate coverage reporting into release process and CI/CD
- **docs**: Enhance coverage report with Material for MkDocs styling

### Documentation

- Add YARD documentation for inspect method and test organization guide
- Add YARD documentation for all constants
- **roadmap**: Modernize with v0.7.1 status and Material styling

### Fixed

- Add v0.7.0 to mkdocs and automate nav updates
- **coverage**: Properly handle SimpleCov :nocov: markers in analysis
- **docs**: Move Security Policy to About section in navigation
- Resolve RuboCop violations for CI/CD compliance
- Update release task to handle GitHub Actions gem publishing
- Resolve final RuboCop issues in release task

### Miscellaneous Tasks

- Fix all RuboCop violations and prepare for v0.7.1 release
- Remove .rubocop_todo.yml after fixing all violations

### Refactor

- Streamline release process for GitHub Actions
- Phase 1 modularization - extract JuniperFile, EnvironmentHelpers, and Validation
- Reorganize directory structure to follow Train plugin conventions
- Phase 2 modularization - extract CommandExecutor and ErrorHandling
- Phase 3 modularization - extract SSHSession and BastionProxy
- DRY improvements for v0.7.1
- Fix all RuboCop complexity issues without using todos
- **docs**: Reorganize navigation for better user experience

### Testing

- Fix platform edge case test and boost coverage to 99.75%
- Achieve 100% code coverage 🎯

## [0.7.0] - 2025-06-23

### Added

- Add security enhancements and input validation
- V0.7.0 - enhanced security, YARD docs, and Windows support

### Documentation

- Update roadmap and fix documentation issues

### Fixed

- Empty environment variables no longer override CLI flags
- Remove Brakeman from security tasks

### Miscellaneous Tasks

- Update .gitignore for untracked files

### Refactor

- Apply DRY principles throughout codebase
- Extract common version detection pattern

### Styling

- Fix RuboCop offenses in connection files

## [0.6.2] - 2025-06-19

### Fixed

- Windows FFI compatibility and mock mode platform detection

## [0.6.1] - 2025-06-18

### Fixed

- Simplify release workflow to use API key directly

## [0.6.0] - 2025-06-18

## [0.5.8] - 2025-06-18

### Fixed

- Use bundler/gem_tasks for standard release workflow
- Rubocop style violation in release.rake

### Refactor

- Integrate custom release tasks with bundler standard flow

## [0.5.7] - 2025-06-18

### Fixed

- Use manual gem push with trusted publishing credentials

## [0.5.6] - 2025-06-18

### Fixed

- Add release task for rubygems/release-gem action

## [0.5.5] - 2025-06-18

### Added

- Prepare workflow for RubyGems trusted publishing

## [0.5.4] - 2025-06-18

### Fixed

- Use manual gem push with API key for RubyGems publishing

## [0.5.3] - 2025-06-18

### Fixed

- Use API key authentication for RubyGems publishing

## [0.5.2] - 2025-06-18

### Fixed

- Update release process to include Gemfile.lock

### Miscellaneous Tasks

- Update Gemfile.lock for version 0.5.1

## [0.5.1] - 2025-06-18

### Added

- Resolve dependency conflicts and establish bundle development workflow
- Comprehensive security infrastructure and development workflow improvements
- Comprehensive CI/CD improvements and code quality enhancements
- Complete repository separation and documentation restructure
- Implement Release Please for automated changelog and releases
- Implement RuboCop-style release process with local changelog generation

### Documentation

- Update CHANGELOG.md for v0.5.0 and improve release workflow

### Fixed

- Remove large VM images from repository
- Add x86_64-linux platform to Gemfile.lock for GitHub Actions
- Resolve CI/CD failures in security workflows
- Remove redundant security scanning and Brakeman
- Resolve RuboCop style violations in security scanner
- Remove TruffleHog from custom security scanner
- Remove extra blank line in security scanner
- Address RuboCop violations in release.rake

### Miscellaneous Tasks

- Cleanup security infrastructure and fix test suite

<!-- generated by git-cliff -->

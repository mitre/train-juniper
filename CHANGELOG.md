# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - 2025-06-18

### Added
- Comprehensive CI/CD improvements with GitHub Actions workflows
- Automated changelog generation with git-cliff
- Complete repository separation from tutorial content
- Enhanced security infrastructure with TruffleHog, Brakeman, and bundler-audit integration

### Changed
- Updated all GitHub Actions to latest versions with proper permissions
- Improved Ruby version consistency across all workflows
- Restructured documentation to focus on plugin usage
- Enhanced security test coverage and reliability

### Fixed
- All RuboCop violations resolved (1,412 → 0 offenses)
- Security tests now properly validate platform family as 'bsd'
- Default test suite now includes security tests
- Improved error handling in security setup scripts

### Removed
- Tutorial content moved to separate train-plugin-development-guide repository
- Redundant security checking scripts replaced by industry-standard tools

## [0.4.0] - 2025-06-17

### Added
- Enhanced Material Design documentation with MkDocs
- Comprehensive JSON/XML structured output examples
- Professional admonitions, icons, and tabbed content
- Call-to-action buttons and improved navigation
- Environment variable cleanup for better test isolation
- Comprehensive security testing framework
- Enhanced error handling and edge case coverage

### Changed  
- Updated documentation to focus on plugin usage (tutorial moved to separate repository)
- Improved proxy/bastion authentication patterns with comprehensive examples
- Enhanced installation instructions with multiple methods
- Standardized all Markdown files to use .md extension

### Fixed
- Test isolation issues preventing consistent test results
- Environment variable pollution between test files
- Repository structure cleanup for production readiness

## [0.3.0] - 2025-06-16

### Added
- Production-ready SSH connectivity with net-ssh-telnet integration
- Comprehensive proxy and bastion host support with multiple authentication patterns
- Platform detection with performance caching
- Mock mode for testing without hardware
- Security infrastructure and audit capabilities

## [0.2.0] - 2025-06-16

### Added
- Enhanced proxy authentication standardization
- Bundle development workflow documentation
- Dependency conflict resolution

## [0.1.0] - 2025-01-16

### Added
- Initial release of train-juniper plugin
- SSH connectivity to Juniper Networks JunOS devices
- Support for InSpec compliance testing on Juniper infrastructure
- Platform detection for JunOS devices and version parsing
- Command execution with JunOS CLI prompt handling
- Configuration file inspection via pseudo-file operations
- Mock mode for testing without real hardware
- Environment variable auto-detection for connection parameters
- Bastion host and proxy command support for enterprise networks
- Comprehensive test suite with 82%+ code coverage
- Security testing framework with credential protection
- Complete Train Plugin Development Guide (17 modules)

### Security
- FFI dependency pinned to ~> 1.16.0 for InSpec compatibility
- Secure credential handling with no password exposure in logs
- Input sanitization and command injection prevention

### Dependencies
- train-core ~> 3.12.13 (lightweight Train core)
- net-ssh ~> 7.0 (SSH connectivity)
- ffi ~> 1.16.0 (InSpec compatibility)

[Unreleased]: https://github.com/mitre/train-juniper/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/mitre/train-juniper/releases/tag/v0.1.0
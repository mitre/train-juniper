# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
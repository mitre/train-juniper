# Contributing to Train-Juniper

Thank you for your interest in contributing to the Train-Juniper plugin! We welcome contributions from the community.

## Development Workflow

We use a standard GitFlow workflow:

1. **Fork** the repository on GitHub
2. **Clone** your fork locally
3. **Create a feature branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
4. **Make your changes** with appropriate tests
5. **Run the test suite** to ensure everything passes:
   ```bash
   bundle install
   bundle exec rake test
   ```
6. **Commit your changes** with clear, descriptive messages
7. **Push** to your fork and **create a Pull Request**

## Code Requirements

### Testing
- All new functionality must include tests
- Tests must pass: `bundle exec rake test`
- Maintain or improve code coverage (currently 82%+)

### Code Style
- Follow existing Ruby style conventions
- Run linting: `bundle exec rubocop`
- No RuboCop violations

### Documentation
- Update README.md for user-facing changes
- Add inline documentation for new methods
- Update relevant documentation modules in `docs/plugin-development/`

## Types of Contributions

### Bug Reports
- Use GitHub Issues with the "bug" label
- Include steps to reproduce
- Provide InSpec and Ruby version information
- Include relevant log output with `-l debug`

### Feature Requests
- Open a GitHub Issue with the "enhancement" label
- Describe the use case and expected behavior
- Discuss implementation approach before coding

### Code Contributions
- Bug fixes
- New features
- Documentation improvements
- Test coverage improvements

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR-USERNAME/train-juniper.git
cd train-juniper

# Install dependencies
bundle install

# Run tests
bundle exec rake test

# Build and test plugin locally
gem build train-juniper.gemspec
inspec plugin install ./train-juniper-0.1.0.gem
```

## Testing Guidelines

### Unit Tests
- Test all public methods
- Mock external dependencies
- Fast execution (< 5 seconds total)

### Integration Tests
- Test real SSH connectivity patterns
- Use containerized environments when possible
- Document any manual testing requirements

### Security Testing
- Run security tests: `bundle exec ruby test/security/security_test.rb`
- Check for credential exposure
- Validate input sanitization

## Pull Request Process

1. **Update Documentation**: Ensure README and relevant docs are updated
2. **Test Coverage**: Maintain or improve test coverage percentage
3. **Security Review**: Run security tests and audit dependencies
4. **Code Review**: Address feedback from maintainers
5. **Merge**: Maintainers will merge approved PRs

## Release Process

Releases are managed by project maintainers:

1. Version bump in `lib/train-juniper/version.rb`
2. Update `CHANGELOG.md`
3. Create release tag
4. Publish to RubyGems.org
5. Update GitHub Pages documentation

## Getting Help

- **Questions**: Open a GitHub Discussion or Issue
- **Real-time help**: Email [saf@mitre.org](mailto:saf@mitre.org)
- **Security issues**: Email [saf-security@mitre.org](mailto:saf-security@mitre.org)

## Community

- Follow our [Code of Conduct](CODE_OF_CONDUCT.md)
- Be respectful and collaborative
- Help others learn and contribute

## License

By contributing, you agree that your contributions will be licensed under the same Apache-2.0 license that covers the project.
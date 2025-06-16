# Packaging and Publishing

Creating production-ready gems and publishing Train plugins to RubyGems for community use.

## Table of Contents

1. [Gemspec Configuration](#gemspec-configuration)
2. [Version Management](#version-management)
3. [Documentation Requirements](#documentation-requirements)
4. [Licensing and Legal](#licensing-and-legal)
5. [Building and Testing Gems](#building-and-testing-gems)
6. [Publishing to RubyGems](#publishing-to-rubygems)
7. [InSpec Plugin Installation](#inspec-plugin-installation)
8. [Maintenance and Updates](#maintenance-and-updates)

---

## Gemspec Configuration

### Standard Gemspec Structure

```ruby
# train-yourname.gemspec
lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "train-yourname/version"

Gem::Specification.new do |spec|
  # Essential metadata
  spec.name          = "train-yourname"
  spec.version       = TrainPlugins::YourName::VERSION
  spec.authors       = ["Your Name", "Team Name"]
  spec.email         = ["your.email@example.com"]
  spec.summary       = "Train plugin for YourSystem devices"
  spec.description   = "Enables InSpec compliance testing for YourSystem infrastructure via SSH/API"
  spec.homepage      = "https://github.com/yourorg/train-yourname"
  spec.license       = "Apache-2.0"

  # Required Ruby version
  spec.required_ruby_version = ">= 3.0.0"

  # File inclusion
  spec.files = %w{
    README.md LICENSE NOTICE CODE_OF_CONDUCT.md
    train-yourname.gemspec Gemfile Rakefile
  } + Dir.glob("lib/**/*", File::FNM_DOTMATCH).reject { |f| File.directory?(f) }

  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "train-core", "~> 3.12"
  spec.add_dependency "net-ssh", "~> 7.0"

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rubocop", "~> 1.21"
end
```

### Community Plugin Standards

Based on research of successful community plugins:

```ruby
# Following train-rest and train-awsssm patterns
spec.name          = "train-yourname"           # Always prefixed with train-
spec.version       = TrainPlugins::YourName::VERSION
spec.license       = "Apache-2.0"              # Standard for Train ecosystem
spec.required_ruby_version = ">= 3.0.0"        # Modern Ruby requirement

# Use train-core for lighter dependency
spec.add_dependency "train-core", "~> 3.12"

# Be specific with versions for security
spec.add_dependency "net-ssh", "~> 7.0"        # Not ">= 7.0"
spec.add_dependency "rest-client", "~> 2.1"    # Not ">= 2.0"
```

### File Inclusion Best Practices

```ruby
# Include essential files
essential_files = %w{
  README.md 
  LICENSE 
  NOTICE 
  CODE_OF_CONDUCT.md
  train-yourname.gemspec 
  Gemfile 
  Rakefile
}

# Include all lib files but exclude directories
lib_files = Dir.glob("lib/**/*", File::FNM_DOTMATCH).reject { |f| File.directory?(f) }

# Combine for complete file list
spec.files = essential_files + lib_files

# Alternative approach for more control
spec.files = `git ls-files -z`.split("\x0").reject do |f|
  f.match(%r{^(test|spec|features)/})
end
```

### Metadata Enhancement

```ruby
spec.metadata = {
  "bug_tracker_uri"   => "https://github.com/yourorg/train-yourname/issues",
  "changelog_uri"     => "https://github.com/yourorg/train-yourname/blob/main/CHANGELOG.md",
  "documentation_uri" => "https://github.com/yourorg/train-yourname/blob/main/README.md",
  "homepage_uri"      => "https://github.com/yourorg/train-yourname",
  "source_code_uri"   => "https://github.com/yourorg/train-yourname",
  "wiki_uri"          => "https://github.com/yourorg/train-yourname/wiki",
  
  # RubyGems security
  "rubygems_mfa_required" => "true"
}
```

---

## Version Management

### Semantic Versioning

Follow [semantic versioning](https://semver.org/) strictly:

```ruby
# lib/train-yourname/version.rb
module TrainPlugins
  module YourName
    VERSION = "1.2.3".freeze
  end
end
```

**Version Format**: `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes to plugin API
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

### Version Lifecycle

```ruby
# Development versions
VERSION = "0.1.0".freeze    # Initial development
VERSION = "0.2.0".freeze    # Added platform detection
VERSION = "0.3.0".freeze    # Added proxy support

# Pre-release versions
VERSION = "1.0.0.alpha.1".freeze    # Alpha release
VERSION = "1.0.0.beta.1".freeze     # Beta release
VERSION = "1.0.0.rc.1".freeze       # Release candidate

# Production versions
VERSION = "1.0.0".freeze    # First stable release
VERSION = "1.0.1".freeze    # Bug fix
VERSION = "1.1.0".freeze    # New features
VERSION = "2.0.0".freeze    # Breaking changes
```

### Changelog Management

```markdown
# CHANGELOG.md

## [Unreleased]
### Added
- New feature in development

## [1.1.0] - 2023-12-01
### Added
- Proxy/bastion host support
- Environment variable configuration
- Comprehensive test suite

### Changed
- Improved error handling for connection failures

### Fixed
- Platform detection timing issues

## [1.0.0] - 2023-11-01
### Added
- Initial release
- SSH connectivity to YourSystem devices
- Basic platform detection
- Mock mode for testing
```

---

## Documentation Requirements

### Essential Documentation Files

#### README.md
```markdown
# Train YourName Plugin

Brief description and usage examples.

## Installation
## Usage
## Configuration Options
## Development
## Contributing
## License
```

#### LICENSE
```
Apache License
Version 2.0, January 2004
http://www.apache.org/licenses/

[Full Apache 2.0 license text]
```

#### NOTICE
```
train-yourname
Copyright 2023 Your Organization

This software contains code derived from the InSpec project
Copyright 2015-2023 Chef Software, Inc.
```

#### CODE_OF_CONDUCT.md
```markdown
# Code of Conduct

## Our Pledge
[Standard code of conduct - often copied from Contributor Covenant]
```

### API Documentation

```ruby
# Document your public API in code
module TrainPlugins
  module YourName
    # Main connection class for YourSystem devices
    #
    # @example Basic usage
    #   transport = Train.create('yourname', host: 'device.com', user: 'admin')
    #   connection = transport.connection
    #   result = connection.run_command('show version')
    #
    # @example With proxy
    #   transport = Train.create('yourname', {
    #     host: 'internal.device',
    #     user: 'admin',
    #     bastion_host: 'jump.corp.com'
    #   })
    class Connection < Train::Plugins::Transport::BaseConnection
```

### Usage Examples

```ruby
# examples/basic_usage.rb
require 'train-yourname'

# Basic connection
transport = Train.create('yourname', {
  host: 'device.example.com',
  user: 'admin',
  password: 'secret'
})

connection = transport.connection

# Execute commands
result = connection.run_command('show version')
puts result.stdout

# File operations
config = connection.file('/config/system').content
puts config
```

---

## Licensing and Legal

### Apache 2.0 License (Recommended)

Apache 2.0 is the standard license for Train ecosystem plugins:

**Benefits:**
- Compatible with InSpec and Train
- Allows commercial use
- Provides patent protection
- Well understood by enterprises

### License Headers

```ruby
# lib/train-yourname/connection.rb
#
# Copyright 2023 Your Organization
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "train"
# ... rest of file
```

### NOTICE File Requirements

```
train-yourname
Copyright 2023 Your Organization

This software contains code derived from:

1. InSpec Project
   Copyright 2015-2023 Chef Software, Inc.
   Licensed under Apache License 2.0

2. Train Project  
   Copyright 2015-2023 Chef Software, Inc.
   Licensed under Apache License 2.0

3. [Any other dependencies with required attribution]
```

### Trademark Considerations

- Don't use vendor trademarks in gem names without permission
- Use descriptive names: `train-cisco-ios` not `train-cisco`
- Include trademark disclaimers in README if needed

---

## Building and Testing Gems

### Local Gem Building

```bash
# Build gem locally
gem build train-yourname.gemspec

# Check gem contents
tar -tf train-yourname-1.0.0.gem

# Install locally for testing
gem install train-yourname-1.0.0.gem

# Test with InSpec
inspec plugin list
inspec detect -t yourname://test-device
```

### Gem Validation

```bash
# Validate gemspec
gem build train-yourname.gemspec --verbose

# Check for common issues
gem specification train-yourname-1.0.0.gem

# Lint gemspec
rubocop train-yourname.gemspec

# Security scan
bundle audit check --update
```

### Pre-release Testing

```ruby
# Rakefile tasks for release preparation
task :build do
  system "gem build train-yourname.gemspec"
end

task :install => :build do
  gem_file = Dir["train-yourname-*.gem"].first
  system "gem install #{gem_file}"
end

task :test_install => :install do
  # Test that plugin loads correctly
  system "ruby -e 'require \"train-yourname\"; puts \"Plugin loaded successfully\"'"
end

task :clean do
  Dir["train-yourname-*.gem"].each { |f| File.delete(f) }
end

task :release_check => [:test, :lint, :build, :test_install] do
  puts "✅ Ready for release"
end
```

---

## Publishing to RubyGems

### RubyGems Account Setup

```bash
# Create RubyGems account at https://rubygems.org

# Set up credentials locally
gem push  # Will prompt for credentials first time

# Or configure explicitly
bundle config set --global rubygems.pkg.github.com USERNAME:TOKEN
```

### First-Time Publishing

```bash
# Final validation
bundle exec rake test
bundle exec rake lint
gem build train-yourname.gemspec

# Publish to RubyGems
gem push train-yourname-1.0.0.gem

# Verify publication
gem search train-yourname
```

### Release Automation

```bash
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: '3.1'
        bundler-cache: true
    
    - name: Run tests
      run: bundle exec rake test
    
    - name: Build gem
      run: gem build train-yourname.gemspec
    
    - name: Publish to RubyGems
      run: |
        mkdir -p ~/.gem
        echo ":rubygems_api_key: ${{ secrets.RUBYGEMS_API_KEY }}" > ~/.gem/credentials
        chmod 0600 ~/.gem/credentials
        gem push train-yourname-*.gem
```

### Version Tagging

```bash
# Create and push release tag
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# GitHub will automatically create release
# if using release workflow
```

---

## InSpec Plugin Installation

### User Installation Process

```bash
# Standard InSpec plugin installation
inspec plugin install train-yourname

# Specific version
inspec plugin install train-yourname -v 1.0.0

# From local gem
inspec plugin install ./train-yourname-1.0.0.gem

# Verify installation
inspec plugin list
```

### Plugin Discovery

InSpec discovers Train plugins automatically:

1. **Gem Installation**: User runs `inspec plugin install train-yourname`
2. **Plugin Scanning**: InSpec scans for gems matching `train-*` pattern
3. **Auto-loading**: InSpec loads plugin when URI scheme matches
4. **Registration**: Plugin registers with Train transport registry

### Usage Validation

```bash
# Test plugin installation
inspec detect -t yourname://test-device

# Run compliance tests
inspec exec compliance-profile -t yourname://production-device

# Interactive shell
inspec shell -t yourname://device

inspec> command('show version').stdout
=> "Version: 1.2.3..."

inspec> os.name
=> "yourname"
```

---

## Maintenance and Updates

### Regular Maintenance Tasks

1. **Dependency Updates**
```bash
bundle update
bundle audit check --update
```

2. **Security Patches**
```bash
# Monitor for vulnerabilities
bundle audit check

# Update vulnerable dependencies
bundle update vulnerable-gem
```

3. **Compatibility Testing**
```bash
# Test against multiple Ruby versions
rvm use 3.0.0 && bundle exec rake test
rvm use 3.1.0 && bundle exec rake test
rvm use 3.2.0 && bundle exec rake test
```

### Deprecation Strategy

```ruby
# Deprecating features gracefully
def old_method
  warn "DEPRECATION: old_method is deprecated, use new_method instead"
  new_method
end

# Version-based deprecation
if TrainPlugins::YourName::VERSION.match?(/^2\./)
  raise "old_method was removed in version 2.0.0, use new_method instead"
end
```

### Breaking Changes

```ruby
# CHANGELOG.md entry for breaking changes
## [2.0.0] - 2024-01-01
### BREAKING CHANGES
- Removed deprecated `old_method`, use `new_method` instead
- Changed default port from 2222 to 22
- Updated minimum Ruby version to 3.1

### Migration Guide
```

### Community Support

```markdown
# README.md support section
## Support

- **Questions**: Open a GitHub discussion
- **Bug Reports**: Create an issue with reproduction steps  
- **Feature Requests**: Open an issue with use case description
- **Security Issues**: Email security@yourorg.com

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request
```

---

## Publishing Checklist

### Pre-Release Checklist

- [ ] All tests passing (`bundle exec rake test`)
- [ ] Code linted (`bundle exec rake lint`)
- [ ] Documentation updated (README, CHANGELOG)
- [ ] Version number updated
- [ ] Security audit clean (`bundle audit`)
- [ ] Gem builds without warnings
- [ ] Local installation works
- [ ] InSpec integration tested

### Release Checklist

- [ ] Tagged in git (`git tag v1.0.0`)
- [ ] Published to RubyGems (`gem push`)
- [ ] GitHub release created
- [ ] Documentation updated
- [ ] Community notified (if appropriate)

### Post-Release Checklist

- [ ] Monitor for installation issues
- [ ] Respond to community feedback
- [ ] Plan next release cycle
- [ ] Update development branch

---

## Key Takeaways

1. **Follow community standards** - Use patterns from successful plugins
2. **Use semantic versioning** - Clear version progression helps users
3. **Include comprehensive documentation** - README, examples, API docs
4. **Test gem building locally** - Catch packaging issues early
5. **Automate releases** - Reduce human error with CI/CD
6. **Plan for maintenance** - Plugins need ongoing security updates
7. **Support the community** - Respond to issues and feature requests

**Next**: Learn about [Best Practices](10-best-practices.md) for production-ready plugins.
# Module 18: RuboCop Configuration for Train Plugins

## Overview

Train plugins have unique patterns and requirements that differ from typical Ruby applications. This module provides reusable RuboCop configurations specifically designed for Train transport plugins, network device plugins, and testing scenarios.

## Table of Contents

1. [Core Train Plugin Configuration](#core-train-plugin-configuration)
2. [Network Device Plugin Configuration](#network-device-plugin-configuration)
3. [Testing Configuration](#testing-configuration)
4. [Complete Example](#complete-example)
5. [Reusable Configuration Modules](#reusable-configuration-modules)
6. [CI/CD Integration](#cicd-integration)

## Core Train Plugin Configuration

### Basic Train Plugin .rubocop.yml

```yaml
# .rubocop.yml for Train plugins
# Basic configuration suitable for all Train transport plugins

AllCops:
  NewCops: enable
  SuggestExtensions: false
  TargetRubyVersion: 3.1
  Exclude:
    - 'vendor/**/*'
    - '.bundle/**/*'
    - 'site/**/*'
    - 'docs/**/*'

# Train plugins use compact module definition
Style/ClassAndModuleChildren:
  Enabled: false  # TrainPlugins::PluginName is standard

# Plugin entry points follow train-* naming convention
Naming/FileName:
  Exclude:
    - 'lib/train-*.rb'  # Standard entry point: lib/train-pluginname.rb

# Plugins have different documentation patterns
Style/Documentation:
  Enabled: false

# String consistency
Style/StringLiterals:
  EnforcedStyle: single_quotes
```

### Plugin-Specific Exclusions

```yaml
# Test files have different patterns
Metrics/BlockLength:
  AllowedMethods:
    - describe
    - context
    - it
  Exclude:
    - '**/*_test.rb'
    - 'test/**/*'
    - 'spec/**/*'
    - '*.gemspec'

# Allow constants in test blocks (MockResult classes)
Lint/ConstantDefinitionInBlock:
  Exclude:
    - 'test/**/*'
```

## Network Device Plugin Configuration

Network device plugins require additional complexity allowances due to SSH connection handling, proxy authentication, and error management.

### Network Device Metrics

```yaml
# Network plugins need longer classes for connection handling
Metrics/ClassLength:
  Max: 300  # Connection classes handle SSH, auth, commands, platform detection

# Network initialization involves many configuration options
Metrics/MethodLength:
  Max: 60   # SSH setup, proxy config, session initialization

Metrics/AbcSize:
  Max: 60   # Complex network setup methods (connect, initialize)

Metrics/CyclomaticComplexity:
  Max: 25   # Network auth and proxy logic

Metrics/PerceivedComplexity:
  Max: 25   # Error handling for network scenarios

Metrics/ModuleLength:
  Max: 120  # Platform detection modules need more space

# Line length - network paths and error messages can be long
Layout/LineLength:
  Max: 140
```

### Network Device Style Exclusions

```yaml
# Complex error handling patterns
Style/GuardClause:
  Enabled: false  # Network plugins have complex nested error handling

# Network commands often return similar results for different scenarios
Style/IdenticalConditionalBranches:
  Enabled: false

# Network plugins commonly exclude sensitive data the same way
Style/HashExcept:
  Enabled: false  # Consistent credential filtering patterns

# Network connection safety patterns
Style/SafeNavigation:
  Exclude:
    - 'lib/**/connection.rb'  # Complex SSH connection logic

# Logger output patterns
Style/GlobalStdStream:
  Exclude:
    - 'lib/**/connection.rb'  # Logger defaults to STDOUT
    - 'test/**/*'
```

### Network-Specific Lint Rules

```yaml
# Platform detection often has expected duplicate mappings
Lint/DuplicateBranch:
  Exclude:
    - 'lib/**/platform.rb'  # Architecture detection has expected duplicates

# Network devices don't support traditional file operations
Lint/UnusedMethodArgument:
  Exclude:
    - 'lib/**/connection.rb'  # upload/download methods intentionally raise NotImplementedError
```

## Testing Configuration

### Test File Patterns

```yaml
# Test-specific configurations
Metrics/BlockLength:
  Max: 50
  AllowedMethods:
    - describe
    - context
    - it
    - shared_examples
    - shared_context
  Exclude:
    - '**/*_test.rb'
    - 'test/**/*'
    - 'spec/**/*'

# Test utilities
Lint/ConstantDefinitionInBlock:
  Exclude:
    - 'test/**/*'  # MockResult, TestConnection classes

Style/GlobalStdStream:
  Exclude:
    - 'test/**/*'  # Test output and debugging

# Test file atomicity
Lint/NonAtomicFileOperation:
  Exclude:
    - 'test/**/*'  # Test cleanup patterns
```

## Complete Example

Here's the complete `.rubocop.yml` we developed for train-juniper:

```yaml
# RuboCop configuration for Train-Juniper plugin
# Network transport plugins have different patterns than typical Ruby apps

AllCops:
  NewCops: enable
  SuggestExtensions: false
  TargetRubyVersion: 3.1
  Exclude:
    - 'site/**/*'
    - 'archive/**/*'
    - 'docs/**/*'
    - 'vendor/**/*'
    - '.bundle/**/*'

# Exclude complex connection logic from auto-correction that breaks code
Style/SafeNavigation:
  Exclude:
    - 'lib/train-juniper/connection.rb'  # Complex SSH connection logic

# Network plugins need longer classes for connection handling
Metrics/ClassLength:
  Max: 300  # Connection classes handle SSH, auth, commands, etc.

# Network initialization involves many configuration options
Metrics/MethodLength:
  Max: 60  # SSH setup, proxy config, session initialization

Metrics/AbcSize:
  Max: 60  # Complex network setup methods

Metrics/CyclomaticComplexity:
  Max: 25  # Network auth and proxy logic (initialize: 20, connect: 18)

Metrics/PerceivedComplexity:
  Max: 25  # Error handling for network scenarios

Metrics/ModuleLength:
  Max: 120  # Platform detection modules need more space

# Test files have naturally long describe blocks
Metrics/BlockLength:
  Max: 50  # Allow longer blocks for gemspec and test files
  AllowedMethods:
    - describe
    - context
    - it
  Exclude:
    - '**/*_test.rb'
    - 'test/**/*'
    - 'spec/**/*'
    - '*.gemspec'

# Line length - allow longer lines for network config
Layout/LineLength:
  Max: 140  # Network paths and error messages can be long

# Allow constants in test blocks (MockResult class)
Lint/ConstantDefinitionInBlock:
  Exclude:
    - 'test/**/*'

# File naming - train-juniper.rb is the standard entry point name
Naming/FileName:
  Exclude:
    - 'lib/train-juniper.rb'

# String literals - relax for network plugins
Style/StringLiterals:
  EnforcedStyle: single_quotes

# Guard clause - can be problematic with complex error handling
Style/GuardClause:
  Enabled: false  # Network plugins have complex nested error handling

# Identical conditional branches - can break heredoc error messages
Style/IdenticalConditionalBranches:
  Enabled: false  # Network plugins return similar results for different paths

# Allow compact module definition for plugins  
Style/ClassAndModuleChildren:
  Enabled: false  # Train plugins use compact TrainPlugins::PluginName format

# Allow STDOUT for logger output in network plugins
Style/GlobalStdStream:
  Exclude:
    - 'lib/train-juniper/connection.rb'  # Logger defaults to STDOUT
    - 'test/**/*'  # Test files may use STDOUT

# Platform detection has expected duplicate architecture mappings
Lint/DuplicateBranch:
  Exclude:
    - 'lib/train-juniper/platform.rb'  # Platform arch detection has expected duplicates
  
# Documentation requirements
Style/Documentation:
  Enabled: false  # Network plugins have different doc patterns
```

## Reusable Configuration Modules

### Creating Modular Configurations

You can split RuboCop configuration into reusable modules:

```yaml
# config/rubocop/train_plugin_base.yml
AllCops:
  NewCops: enable
  SuggestExtensions: false

Style/ClassAndModuleChildren:
  Enabled: false

Naming/FileName:
  Exclude:
    - 'lib/train-*.rb'

Style/Documentation:
  Enabled: false
```

```yaml
# config/rubocop/network_device.yml
Metrics/ClassLength:
  Max: 300

Metrics/MethodLength:
  Max: 60

Style/GuardClause:
  Enabled: false

Layout/LineLength:
  Max: 140
```

```yaml
# config/rubocop/testing.yml
Metrics/BlockLength:
  AllowedMethods:
    - describe
    - context
    - it
  Exclude:
    - 'test/**/*'

Lint/ConstantDefinitionInBlock:
  Exclude:
    - 'test/**/*'
```

### Using Modular Configuration

```yaml
# .rubocop.yml
inherit_from:
  - config/rubocop/train_plugin_base.yml
  - config/rubocop/network_device.yml
  - config/rubocop/testing.yml

# Plugin-specific overrides
AllCops:
  TargetRubyVersion: 3.1
  Exclude:
    - 'docs/**/*'
```

## CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/ruby.yml
name: Ruby

on: [push, pull_request]

jobs:
  rubocop:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Set up Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: 3.1
        bundler-cache: true
    - name: Run RuboCop
      run: bundle exec rubocop
  
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Set up Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: 3.1
        bundler-cache: true
    - name: Run tests
      run: bundle exec rake test
```

### RuboCop Todo Management

For existing projects with many violations:

```bash
# Generate .rubocop_todo.yml
bundle exec rubocop --auto-gen-config

# Gradually fix categories
bundle exec rubocop --only Style/StringLiterals --auto-correct
bundle exec rubocop --only Layout/LineLength --auto-correct
```

## Key Takeaways

1. **Network plugins have unique requirements** that justify relaxed complexity metrics
2. **Protect critical code** from auto-corrections that can break functionality
3. **Modular configuration** enables reuse across multiple Train plugins
4. **Test files need different rules** than production code
5. **CI/CD integration** ensures code quality standards are maintained
6. **Gradual adoption** is possible for existing codebases

## Best Practices

1. **Start with the base Train plugin configuration**
2. **Add network device extensions only if needed**
3. **Document why specific rules are disabled**
4. **Use auto-correct carefully** - always test after auto-corrections
5. **Exclude specific files/patterns** rather than disabling rules globally
6. **Review RuboCop output regularly** in CI/CD pipelines

## Next Steps

- **Module 19**: Advanced Testing Patterns for Train Plugins
- **Module 20**: Performance Optimization for Network Transports
- **Module 21**: Contributing to the Train Plugin Ecosystem

---

*This module provides battle-tested RuboCop configurations from the train-juniper plugin development experience.*
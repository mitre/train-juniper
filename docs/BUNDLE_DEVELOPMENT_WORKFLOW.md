# Bundle Development Workflow for Train Plugins

## Overview

This document captures the **game-changing development workflow** discovered during train-juniper development that enables **rapid iteration without gem rebuilds**.

## The Problem with Traditional Plugin Development

**Standard plugin development cycle:**
```bash
# SLOW - Traditional approach:
1. Edit plugin code
2. gem build train-plugin.gemspec  
3. inspec plugin uninstall train-plugin
4. inspec plugin install train-plugin-x.x.x.gem
5. inspec shell -t transport://
6. Test and debug
7. Repeat entire cycle for each change
```

**Problems:**
- **5-10+ commands** per iteration
- **Gem rebuild time** (even for small changes)
- **Version management complexity** 
- **Plugin install/uninstall overhead**
- **Risk of conflicts** between versions

## The Bundle Integration Solution

**Rapid development cycle:**
```bash
# FAST - Bundle approach:
1. Edit plugin code
2. bundle exec inspec shell -t transport://
3. Test immediately
4. Repeat steps 1-3 only
```

**Benefits:**
- **2 commands** per iteration instead of 7+
- **Immediate changes** - no gem rebuilds
- **No version management** - always uses current code
- **No install/uninstall** overhead
- **Clean isolation** from global plugins

## Implementation Steps

### 1. Set Up InSpec Source Development

```bash
# Clone InSpec (choose your version)
git clone https://github.com/inspec/inspec.git
cd inspec

# Use specific branch if needed
git checkout inspec-7  # or main

# Install dependencies
bundle install
```

### 2. Add Plugin to InSpec Gemfile

```ruby
# In InSpec's Gemfile, add your plugin with path reference:
gem 'train-yourplugin', path: '/path/to/your/train-plugin'
```

**Example:**
```ruby
# Add to InSpec Gemfile:
gem 'train-juniper', path: '/Users/alippold/github/mitre/train-juniper'
```

### 3. Update Bundle and Verify

```bash
# Install with path dependency
bundle install

# Verify plugin is loaded from source
bundle exec inspec plugin list
# Should show your plugin but NOT in the main list
# (Bundle-managed plugins don't appear in plugin list)

# Test plugin loading
bundle exec inspec shell -t yourplugin://
```

### 4. Version Marker for Confirmation

**In your plugin version file:**
```ruby
# lib/train-yourplugin/version.rb
VERSION = "0.4.0-dev".freeze  # Add -dev suffix
```

**Verification:**
```bash
bundle exec inspec shell -t yourplugin://
# Should show: Release: 0.4.0-dev
# Confirms bundle is using your local code
```

## Development Workflow

### Rapid Iteration Pattern

```bash
# 1. Edit plugin code
vim lib/train-yourplugin/connection.rb

# 2. Test immediately 
bundle exec inspec shell -t yourplugin://

# 3. Test specific functionality
inspec> command('test command')
inspec> os.family

# 4. Exit and repeat
exit
# Back to step 1
```

### Advanced Development Techniques

**Debugging with Pry:**
```ruby
# Add to your plugin code
require 'pry'
binding.pry  # Debugging breakpoint
```

```bash
# Run with pry
bundle exec inspec shell -t yourplugin://
# Pry will activate at breakpoint
```

**Testing Specific Methods:**
```bash
bundle exec inspec shell -t yourplugin://
inspec> connection.run_command_via_connection('show version')
inspec> connection.platform.name
inspec> connection.platform.families
```

**Real-time Log Monitoring:**
```ruby
# In plugin code - add detailed logging
@logger.debug("Testing new feature: #{variable}")
```

```bash
# Run with debug logging
bundle exec inspec shell -t yourplugin:// -l debug
```

## Verification and Testing

### Confirm Bundle Integration

**1. Check Plugin Loading:**
```bash
bundle exec inspec shell -t yourplugin://
# Should work without "plugin not found" errors
```

**2. Verify Version Marker:**
```bash
# Should show your development version
Release: 0.4.0-dev  # or your dev version marker
```

**3. Test Bundle Isolation:**
```bash
# Global plugin list shouldn't show your plugin
inspec plugin list

# Bundle context should load your plugin
bundle exec inspec shell -t yourplugin://
```

### Troubleshooting Bundle Issues

**Plugin Not Found:**
```bash
# Check Gemfile path is correct
bundle info train-yourplugin

# Verify bundle can find plugin
bundle exec ruby -e "require 'train-yourplugin'; puts 'Plugin loaded'"
```

**Version Conflicts:**
```bash
# Uninstall global version first
inspec plugin uninstall train-yourplugin

# Clear bundle cache if needed
bundle exec bundle clean --force
bundle install
```

**Path Issues:**
```ruby
# Use absolute paths in Gemfile
gem 'train-yourplugin', path: '/absolute/path/to/plugin'
# NOT relative paths like '../train-yourplugin'
```

## Integration with Tutorial Modules

### Module 2: Development Setup
- Add bundle workflow as preferred development method
- Include InSpec source setup instructions
- Document version marker strategy

### Module 8: Testing Strategies  
- Bundle development testing patterns
- Rapid iteration debugging techniques
- Pry integration for development

### Module 10: Best Practices
- Development workflow recommendations
- Bundle vs gem install trade-offs
- Team development considerations

### Module 11: Troubleshooting
- Bundle integration debugging
- Path resolution issues
- Version conflict resolution

## Advanced Patterns

### Multi-Plugin Development

```ruby
# Gemfile for multiple plugins
gem 'train-plugin1', path: '/path/to/plugin1'
gem 'train-plugin2', path: '/path/to/plugin2'  
gem 'train-plugin3', path: '/path/to/plugin3'
```

### Team Development

```ruby
# Gemfile with conditional paths
plugin_path = ENV['TRAIN_PLUGIN_PATH'] || '/default/path'
gem 'train-yourplugin', path: plugin_path
```

```bash
# Team member usage
export TRAIN_PLUGIN_PATH="/their/path/to/plugin"
bundle install
bundle exec inspec shell -t yourplugin://
```

### CI/CD Integration

```yaml
# GitHub Actions example
- name: Test Plugin with Bundle
  run: |
    echo "gem 'train-plugin', path: '${GITHUB_WORKSPACE}'" >> Gemfile
    bundle install
    bundle exec inspec shell -t plugin:// --no-distinct-exit
```

## Performance Comparison

### Traditional Workflow Timing
```
Edit code:           10s
Gem build:           5-15s  
Plugin uninstall:    5-10s
Plugin install:      10-20s
InSpec shell:        5-10s
Total per cycle:     35-65s
```

### Bundle Workflow Timing
```
Edit code:           10s
Bundle exec:         2-5s
Total per cycle:     12-15s
```

**Result: 3-5x faster development cycles**

## Conclusion

The bundle development workflow is **essential for productive Train plugin development**. It:

- **Reduces iteration time** by 3-5x
- **Eliminates gem management overhead**
- **Enables rapid debugging** with pry
- **Provides clean development isolation**
- **Scales to team development**

**Recommendation**: Always use bundle development workflow for active plugin development, only use gem installation for final testing and distribution.

This pattern should be the **default approach** taught in Train plugin development tutorials.
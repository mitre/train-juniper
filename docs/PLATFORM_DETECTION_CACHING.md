# Platform Detection Caching - Performance Optimization Guide

## Overview

This document captures critical performance optimization patterns discovered during train-juniper development. Specifically, it addresses the performance issue where InSpec resources trigger excessive platform detection calls, causing significant slowdowns.

## Problem Summary

### Performance Issue Identified
**Symptom**: `inspec.json({command: 'show version | display json'})` causing extremely slow performance with excessive debug output showing 10+ duplicate platform detection calls.

**Root Cause**: Platform detection methods lacking caching, called repeatedly for every InSpec resource usage instead of being cached per connection.

**Impact**: 
- Severe performance degradation when using InSpec JSON resources
- Excessive SSH command execution (`show version` called 10+ times per resource)
- Poor user experience with slow compliance testing

### Debug Evidence
```bash
# Before caching fix - excessive output:
DEBUG -- : Executing: show version
DEBUG -- : Detected JunOS version: 23.4R1.9
DEBUG -- : Executing: show version  # DUPLICATE!
DEBUG -- : Detected JunOS version: 23.4R1.9
DEBUG -- : Executing: show version  # DUPLICATE!
DEBUG -- : Detected JunOS version: 23.4R1.9
# ... repeated 10+ times for single JSON resource
```

## Solution: Platform Detection Caching

### Caching Strategy
Implement instance variable caching for platform detection methods with shared cache optimization to prevent duplicate command execution.

### Implementation Pattern

#### 1. Version Detection Caching
```ruby
def detect_junos_version
  # Return cached version if already detected
  return @detected_junos_version if defined?(@detected_junos_version)
  
  # Only try version detection if we have an active connection
  return @detected_junos_version = nil unless respond_to?(:run_command_via_connection)
  return @detected_junos_version = nil if @options&.dig(:mock) # Skip in mock mode
  
  begin
    # Check if connection is ready before running commands
    return @detected_junos_version = nil unless connected?
    
    # Execute 'show version' command to get JunOS information
    result = run_command_via_connection("show version")
    return @detected_junos_version = nil unless result&.exit_status == 0
    
    # Cache the result for architecture detection to avoid duplicate calls
    @cached_show_version_result = result
    
    # Parse JunOS version from output using multiple patterns
    version = extract_version_from_output(result.stdout)
    
    if version
      logger&.debug("Detected JunOS version: #{version}")
      @detected_junos_version = version
    else
      logger&.debug("Could not parse JunOS version from: #{result.stdout[0..100]}")
      @detected_junos_version = nil
    end
  rescue => e
    # If version detection fails, log and return nil
    logger&.debug("JunOS version detection failed: #{e.message}")
    @detected_junos_version = nil
  end
end
```

#### 2. Architecture Detection with Shared Cache
```ruby
def detect_junos_architecture
  # Return cached architecture if already detected
  return @detected_junos_architecture if defined?(@detected_junos_architecture)
  
  # Only try architecture detection if we have an active connection
  return @detected_junos_architecture = nil unless respond_to?(:run_command_via_connection)
  return @detected_junos_architecture = nil if @options&.dig(:mock) # Skip in mock mode
  
  begin
    # Check if connection is ready before running commands
    return @detected_junos_architecture = nil unless connected?
    
    # Reuse version detection result to avoid duplicate 'show version' calls
    # Both version and architecture come from the same command output
    if defined?(@detected_junos_version) && @detected_junos_version
      # We already have the output from version detection, parse architecture from it
      result = @cached_show_version_result
    else
      # Execute 'show version' command and cache the result
      result = run_command_via_connection("show version")
      @cached_show_version_result = result if result&.exit_status == 0
    end
    
    return @detected_junos_architecture = nil unless result&.exit_status == 0
    
    # Parse architecture from output using multiple patterns
    arch = extract_architecture_from_output(result.stdout)
    
    if arch
      logger&.debug("Detected JunOS architecture: #{arch}")
      @detected_junos_architecture = arch
    else
      logger&.debug("Could not parse JunOS architecture from: #{result.stdout[0..100]}")
      @detected_junos_architecture = nil
    end
  rescue => e
    # If architecture detection fails, log and return nil
    logger&.debug("JunOS architecture detection failed: #{e.message}")
    @detected_junos_architecture = nil
  end
end
```

### Key Caching Principles

1. **Instance Variable Caching**: Use `@detected_*` variables to cache results per connection
2. **defined? Check**: Use `defined?(@variable)` to distinguish between cached `nil` and uncached state
3. **Shared Cache**: Use `@cached_show_version_result` to share command output between detection methods
4. **Mock Mode Skip**: Always check `@options&.dig(:mock)` to skip detection in testing
5. **Connection Guards**: Verify connection is ready before executing commands
6. **Graceful Degradation**: Return `nil` on failure, don't crash the plugin

## Testing Caching Behavior

### Version Detection Caching Test
```ruby
it "should cache version detection results" do
  version_output = <<~OUTPUT
    Hostname: lab-srx
    Model: SRX240H2
    Junos: 12.1X47-D15.4
  OUTPUT
  
  test_connection = connection.new(version_output)
  
  # Mock run_command_via_connection to track call count
  call_count = 0
  test_connection.define_singleton_method(:run_command_via_connection) do |cmd|
    call_count += 1
    MockResult.new(version_output, 0)
  end
  
  # First call should execute command
  version1 = test_connection.send(:detect_junos_version)
  _(version1).must_equal("12.1X47-D15.4")
  _(call_count).must_equal(1)
  
  # Second call should use cached result
  version2 = test_connection.send(:detect_junos_version)
  _(version2).must_equal("12.1X47-D15.4")
  _(call_count).must_equal(1) # Should not increase
end
```

### Shared Cache Test
```ruby
it "should share cached result between version and architecture detection" do
  version_output = <<~OUTPUT
    Hostname: lab-srx
    Model: SRX240H2
    Junos: 12.1X47-D15.4
  OUTPUT
  
  test_connection = connection.new(version_output)
  
  # Mock run_command_via_connection to track call count
  call_count = 0
  test_connection.define_singleton_method(:run_command_via_connection) do |cmd|
    call_count += 1
    MockResult.new(version_output, 0)
  end
  
  # First call for version detection
  version = test_connection.send(:detect_junos_version)
  _(version).must_equal("12.1X47-D15.4")
  _(call_count).must_equal(1)
  
  # Architecture detection should reuse the cached result
  arch = test_connection.send(:detect_junos_architecture)
  _(arch).must_equal("x86_64")
  _(call_count).must_equal(1) # Should not increase - shared cache
  
  # Subsequent calls should also use cache
  version2 = test_connection.send(:detect_junos_version)
  arch2 = test_connection.send(:detect_junos_architecture)
  _(version2).must_equal("12.1X47-D15.4")
  _(arch2).must_equal("x86_64") 
  _(call_count).must_equal(1) # Still should not increase
end
```

## Results After Implementation

### Performance Improvement
```bash
# After caching fix - optimal output:
DEBUG -- : Executing: show version
DEBUG -- : Detected JunOS version: 23.4R1.9
DEBUG -- : Detected JunOS architecture: x86_64
# No duplicate calls for subsequent InSpec resource usage
```

### Test Results
- ✅ **116 tests passing**, 282 assertions, 0 failures, 0 errors
- ✅ **74.24% code coverage** (196/264 lines)
- ✅ **Caching verification**: All caching behavior tests pass
- ✅ **Performance verified**: Single command execution per connection

### InSpec Resource Performance
- **Before**: 10+ `show version` calls per JSON resource → ~10+ seconds
- **After**: 1 `show version` call per connection → ~1 second
- **Improvement**: 90%+ performance improvement for InSpec resources

## Best Practices for Train Plugin Developers

### 1. Always Implement Caching
```ruby
# RECOMMENDED: Cache detection results
def detect_version
  return @detected_version if defined?(@detected_version)
  
  # Detection logic...
  @detected_version = parsed_version
end

# AVOID: No caching - causes performance issues
def detect_version
  result = run_command("show version")  # Called repeatedly!
  parse_version(result.stdout)
end
```

### 2. Use Shared Cache for Related Detection
```ruby
# RECOMMENDED: Share command output between detections
def detect_version
  return @detected_version if defined?(@detected_version)
  
  result = get_or_execute_version_command
  @detected_version = parse_version(result.stdout)
end

def detect_architecture
  return @detected_architecture if defined?(@detected_architecture)
  
  result = get_or_execute_version_command  # Reuses cached result
  @detected_architecture = parse_architecture(result.stdout)
end

private

def get_or_execute_version_command
  return @cached_version_result if @cached_version_result
  
  @cached_version_result = run_command_via_connection("show version")
end
```

### 3. Handle Edge Cases
```ruby
def detect_version
  # Check if caching variable is defined (not just truthy)
  return @detected_version if defined?(@detected_version)
  
  # Guard against early execution
  return @detected_version = nil unless respond_to?(:run_command_via_connection)
  return @detected_version = nil unless connected?
  
  # Skip in mock mode
  return @detected_version = nil if @options&.dig(:mock)
  
  # Detection with error handling
  begin
    result = run_command_via_connection("show version")
    @detected_version = result.exit_status == 0 ? parse_version(result.stdout) : nil
  rescue => e
    logger&.debug("Version detection failed: #{e.message}")
    @detected_version = nil
  end
end
```

### 4. Test Caching Thoroughly
```ruby
# Test cache behavior, not just detection accuracy
it "should cache results across multiple calls" do
  # Track command execution count
  call_count = 0
  connection.define_singleton_method(:run_command_via_connection) do |cmd|
    call_count += 1
    MockResult.new("Version: 1.0.0", 0)
  end
  
  # Verify caching prevents duplicate execution
  version1 = connection.detect_version
  version2 = connection.detect_version
  
  _(call_count).must_equal(1)  # Only one execution
  _(version1).must_equal(version2)  # Same result
end
```

## Common Mistakes to Avoid

### 1. Not Using defined? Check
```ruby
# WRONG: Truthy check prevents caching nil results
def detect_version
  return @detected_version if @detected_version  # Fails if version is nil!
  # ...
end

# CORRECT: defined? check allows caching nil
def detect_version
  return @detected_version if defined?(@detected_version)
  # ...
end
```

### 2. Not Sharing Cache Between Related Methods
```ruby
# WRONG: Both methods execute same command
def detect_version
  result = run_command("show version")  # Command execution 1
  parse_version(result.stdout)
end

def detect_model
  result = run_command("show version")  # Command execution 2 - DUPLICATE!
  parse_model(result.stdout)
end

# CORRECT: Share command result
def detect_version
  result = get_version_output
  parse_version(result.stdout)
end

def detect_model
  result = get_version_output  # Reuses cached result
  parse_model(result.stdout)
end
```

### 3. Not Testing Cache Behavior
```ruby
# WRONG: Only test detection accuracy
it "should detect version correctly" do
  version = connection.detect_version
  _(version).must_equal("1.0.0")
end

# CORRECT: Also test caching behavior
it "should cache version detection" do
  call_count = 0
  # Mock and track calls...
  
  version1 = connection.detect_version
  version2 = connection.detect_version
  
  _(call_count).must_equal(1)  # Verify caching
end
```

## Integration with Plugin Development Guide

This caching pattern should be integrated into:

### Module 7: Platform Detection
- Add section on "Performance Optimization with Caching"
- Include caching implementation patterns
- Document shared cache strategies

### Module 8: Testing Strategies  
- Add caching behavior testing patterns
- Include command execution tracking techniques
- Document performance regression testing

### Module 11: Troubleshooting
- Add section on "Performance Issues"
- Document debugging excessive command execution
- Include caching verification techniques

## Key Takeaways

1. **InSpec triggers multiple platform detection calls** - Resources like `json()` can cause 10+ duplicate detections
2. **Caching is essential for performance** - Use instance variables with `defined?` checks
3. **Share cache between related methods** - Version and architecture often come from same command
4. **Test caching behavior explicitly** - Verify command execution count, not just detection accuracy
5. **Handle edge cases gracefully** - Mock mode, connection timing, error conditions
6. **Performance improvement is dramatic** - 90%+ improvement with proper caching

## Conclusion

Platform detection caching is a **critical performance optimization** for Train plugins. Without it, plugins suffer severe performance degradation when used with InSpec resources. This pattern should be considered **mandatory** for any Train plugin that performs detection commands.

The implementation is straightforward but requires attention to edge cases and thorough testing. The performance benefits are substantial and directly impact user experience with InSpec compliance testing.
# Platform Detection

Understanding Train's platform detection system and implementing reliable platform identification for your plugin.

## Table of Contents

1. [What is Platform Detection?](#what-is-platform-detection)
2. [Platform Detection Strategies](#platform-detection-strategies)
3. [Force Platform Pattern (Recommended)](#force-platform-pattern-recommended)
4. [Detection Command Pattern](#detection-command-pattern)
5. [Platform Families and Registry](#platform-families-and-registry)
6. [Version Detection Implementation](#version-detection-implementation)
7. [Testing Platform Detection](#testing-platform-detection)
8. [Troubleshooting Detection Issues](#troubleshooting-detection-issues)

---

## What is Platform Detection?

Platform detection tells InSpec what type of system it's connected to. This affects:

- **Available Resources**: Which InSpec resources work (e.g., `windows_feature` vs `package`)
- **File Path Handling**: How paths are interpreted (`/etc/passwd` vs `C:\Windows`)
- **Command Behavior**: Default shell, command syntax, output formats
- **Test Assumptions**: What capabilities the target system has

### Platform Information Structure

```ruby
# Example platform detection result
{
  name: "juniper",           # Platform identifier
  families: ["network"],     # Platform family membership
  release: "21.4R3-S1.6",   # Version/release information
  arch: "network",           # Architecture designation
  title: "Juniper JunOS"     # Human-readable name
}
```

### How InSpec Uses Platform Detection

```ruby
# InSpec can conditionally run tests based on platform
describe "SSH configuration" do
  only_if { os.family == 'network' }
  
  describe command('show configuration ssh') do
    its('stdout') { should match /protocol-version v2/ }
  end
end

# Different tests for different platforms
if os.name == 'juniper'
  describe command('show version') do
    its('stdout') { should match /Junos:/ }
  end
elsif os.name == 'cisco-ios'
  describe command('show version') do  
    its('stdout') { should match /Cisco IOS/ }
  end
end
```

---

## Platform Detection Strategies

### Strategy 1: Force Platform (Recommended)

**Use when**: You know exactly what platform your plugin targets

**Benefits**:
- Bypasses Train's automatic detection
- Prevents detection commands running before connection ready
- Standard pattern for dedicated transport plugins
- Faster connection establishment

**When to use**: Network devices, specialized APIs, cloud resources

### Strategy 2: Detection Commands

**Use when**: Your plugin supports multiple related platforms

**Benefits**:
- Automatic platform identification
- Supports plugin families (e.g., multiple Cisco device types)
- Can detect platform variants and versions

**When to use**: Multi-platform plugins, OS family plugins

---

## Force Platform Pattern (Recommended)

Most dedicated transport plugins should use `force_platform!` to bypass automatic detection.

### Basic Implementation

```ruby
# lib/train-yourname/platform.rb
module TrainPlugins::YourName
  module Platform
    PLATFORM_NAME = "yourname".freeze
    
    def platform
      # Register platform in Train's registry
      Train::Platforms.name(PLATFORM_NAME)
        .title("Your Platform Name")
        .in_family("appropriate_family")
      
      # Force platform detection result
      force_platform!(PLATFORM_NAME, {
        release: detect_version || TrainPlugins::YourName::VERSION,
        arch: "network"  # or "cloud", "container", etc.
      })
    end

    private

    def detect_version
      # Optional: Try to detect actual version if connection ready
      return nil if @options&.dig(:mock)
      return nil unless respond_to?(:run_command_via_connection)
      return nil unless connected?
      
      begin
        result = run_command_via_connection("show version")
        return nil unless result.exit_status == 0
        
        extract_version_from_output(result.stdout)
      rescue
        nil  # Graceful fallback to plugin version
      end
    end

    def extract_version_from_output(output)
      # Parse version from command output
      if match = output.match(/Version:\s+([\d\w\.-]+)/)
        match[1]
      end
    end
  end
end
```

### Advanced Force Platform

```ruby
def platform
  # Register platform with detailed information
  Train::Platforms.name(PLATFORM_NAME)
    .title("Juniper JunOS")
    .in_family("network")
    .detect do
      # This block runs only if auto-detection is used
      # For force_platform!, this is bypassed
      true
    end
  
  # Detect additional platform information
  version = detect_version || TrainPlugins::YourName::VERSION
  model = detect_model
  
  force_platform!(PLATFORM_NAME, {
    release: version,
    arch: "network",
    # Additional custom attributes
    model: model,
    family_version: extract_major_version(version)
  })
end

private

def detect_model
  return nil unless connected? && !@options[:mock]
  
  begin
    result = run_command_via_connection("show chassis hardware")
    if match = result.stdout.match(/Model:\s+(\S+)/)
      match[1]
    end
  rescue
    nil
  end
end
```

---

## Detection Command Pattern

For plugins that support multiple related platforms, use detection commands.

### Multi-Platform Implementation

```ruby
module Platform
  def platform
    detect_via_uname
  rescue Train::PlatformDetectionFailed
    detect_via_version_command
  rescue Train::PlatformDetectionFailed
    detect_via_show_version
  end

  private

  def detect_via_uname
    result = run_command_via_connection("uname -a")
    return unless result.exit_status == 0
    
    case result.stdout
    when /Linux/
      detect_linux_variant(result.stdout)
    when /Darwin/
      detect_macos_version(result.stdout)
    else
      raise Train::PlatformDetectionFailed
    end
  end

  def detect_via_version_command
    result = run_command_via_connection("show version")
    return unless result.exit_status == 0
    
    case result.stdout
    when /Junos:/
      detect_junos_platform(result.stdout)
    when /Cisco IOS/
      detect_ios_platform(result.stdout)
    when /Arista/
      detect_eos_platform(result.stdout)
    else
      raise Train::PlatformDetectionFailed
    end
  end

  def detect_junos_platform(output)
    version = extract_junos_version(output)
    model = extract_junos_model(output)
    
    Train::Platforms.name("juniper")
      .title("Juniper JunOS")
      .in_family("network")
    
    force_platform!("juniper", {
      release: version,
      arch: "network",
      model: model
    })
  end
end
```

### Graceful Detection Fallbacks

```ruby
def platform
  # Try multiple detection methods in order of reliability
  platform_info = detect_via_api ||
                   detect_via_version_command ||
                   detect_via_hostname ||
                   fallback_platform_info
  
  apply_platform_info(platform_info)
end

private

def detect_via_api
  return nil unless supports_api?
  
  begin
    response = api_get("/system/info")
    {
      name: response["platform"],
      version: response["version"],
      family: "api"
    }
  rescue
    nil
  end
end

def detect_via_version_command
  return nil unless supports_cli?
  
  begin
    result = run_command_via_connection("version")
    return nil unless result.exit_status == 0
    
    parse_version_output(result.stdout)
  rescue
    nil
  end
end

def fallback_platform_info
  # Last resort - use plugin defaults
  {
    name: PLATFORM_NAME,
    version: TrainPlugins::YourName::VERSION,
    family: "unknown"
  }
end
```

---

## Platform Families and Registry

### Common Platform Families

| Family | Description | Examples |
|--------|-------------|----------|
| `unix` | Unix-like systems | Linux, macOS, BSD |
| `linux` | Linux distributions | Ubuntu, CentOS, RHEL |
| `windows` | Windows systems | Windows Server, Windows 10 |
| `network` | Network devices | Routers, switches, firewalls |
| `cloud` | Cloud APIs | AWS, Azure, GCP |
| `container` | Container systems | Docker, Kubernetes |
| `database` | Database systems | PostgreSQL, MySQL |

### Platform Registry Usage

```ruby
def platform
  # Register your platform in the global registry
  Train::Platforms.name("yourname")
    .title("Your Platform")
    .in_family("network")          # Primary family
    .in_family("unix")             # Can belong to multiple families
    .detect do |platform, conn|
      # Auto-detection logic (if not using force_platform!)
      conn.run_command("show version").stdout.match?(/YourPlatform/)
    end
  
  # Apply the platform
  force_platform!("yourname", platform_attributes)
end
```

### Family Inheritance

```ruby
# Platforms inherit capabilities from their families
Train::Platforms.name("juniper")
  .in_family("network")  # Inherits network device capabilities
  .in_family("unix")     # Also inherits Unix-like file handling

# This allows InSpec to use appropriate resources:
# - Network-specific resources (command, etc.)
# - Unix-style file operations where applicable
```

---

## Version Detection Implementation

### Parsing Version Strings

```ruby
def extract_version_from_output(output)
  return nil if output.nil? || output.empty?
  
  # Try multiple version patterns in order of specificity
  patterns = [
    /Version:\s+([\d\w\.-]+)/,                     # "Version: 1.2.3"
    /Software Release \[([\d\w\.-]+)\]/,           # "Software Release [12.1X47]"
    /version ([\d]+\.[\d]+[\w\.-]*)/i,             # "version 21.4R3"
    /([\d]+\.[\d]+\.[\d]+)/,                       # Generic x.y.z
    /([\d]+\.[\d]+)/                               # Generic x.y
  ]
  
  patterns.each do |pattern|
    match = output.match(pattern)
    return match[1] if match
  end
  
  nil
end
```

### Version Normalization

```ruby
def normalize_version(version_string)
  return nil unless version_string
  
  # Handle different version formats
  case version_string
  when /^(\d+)\.(\d+)\.(\d+)/
    # Standard semantic version
    version_string
  when /^(\d+)\.(\d+)([A-Z]\d+)/
    # Juniper style: 21.4R3
    $1 + "." + $2 + "." + $3
  when /^(\d+)\.(\d+)X(\d+)/
    # Juniper X branch: 12.1X47
    $1 + "." + $2 + ".X" + $3
  else
    # Return as-is if unrecognized
    version_string
  end
end
```

### Version Comparison

```ruby
def version_compare(version1, version2)
  # Convert versions to comparable arrays
  v1_parts = version1.split('.').map { |x| x.to_i rescue 0 }
  v2_parts = version2.split('.').map { |x| x.to_i rescue 0 }
  
  # Pad shorter version with zeros
  max_length = [v1_parts.length, v2_parts.length].max
  v1_parts += [0] * (max_length - v1_parts.length)
  v2_parts += [0] * (max_length - v2_parts.length)
  
  # Compare part by part
  v1_parts <=> v2_parts
end

def version_at_least?(current, minimum)
  version_compare(current, minimum) >= 0
end
```

---

## Testing Platform Detection

### Unit Tests

```ruby
# test/unit/platform_test.rb
describe "Platform Detection" do
  let(:connection) { create_mock_connection }
  
  it "should use force_platform for dedicated plugins" do
    platform = connection.platform
    
    _(platform[:name]).must_equal("yourname")
    _(platform[:families]).must_include("network")
  end
  
  it "should detect version from command output" do
    mock_command_result("show version", "Version: 1.2.3-beta")
    
    platform = connection.platform
    _(platform[:release]).must_equal("1.2.3-beta")
  end
  
  it "should fallback to plugin version if detection fails" do
    mock_command_failure("show version")
    
    platform = connection.platform
    _(platform[:release]).must_equal(TrainPlugins::YourName::VERSION)
  end
  
  it "should parse multiple version formats" do
    test_cases = {
      "Version: 21.4R3-S1.6" => "21.4R3-S1.6",
      "Software Release [12.1X47-D15.4]" => "12.1X47-D15.4",
      "version 15.1(4)M" => "15.1(4)M",
      "Build 1.0.0.123" => "1.0.0"
    }
    
    test_cases.each do |input, expected|
      version = connection.send(:extract_version_from_output, input)
      _(version).must_equal(expected)
    end
  end
end
```

### Integration Tests

```ruby
describe "Platform Detection Integration" do
  
  it "should work with Train.create" do
    transport = Train.create("yourname", mock: true)
    connection = transport.connection
    
    platform = connection.os
    _(platform.name).must_equal("yourname")
    _(platform.family).must_equal("network")
  end
  
  it "should provide platform info to InSpec" do
    # Simulate InSpec usage
    transport = Train.create("yourname", mock: true)
    connection = transport.connection
    
    # Platform info should be available via os method
    os_info = connection.os
    _(os_info[:name]).must_equal("yourname")
    _(os_info[:families]).must_include("network")
  end
end
```

---

## Troubleshooting Detection Issues

### Common Problems

#### 1. Detection Commands Run Too Early

```ruby
# WRONG: Detection runs before connection ready
def platform
  result = run_command_via_connection("show version")  # May fail!
  # ...
end

# CORRECT: Guard against early execution
def detect_version
  return nil unless respond_to?(:run_command_via_connection)
  return nil unless connected?
  # ...
end
```

#### 2. Platform Not Registered

```ruby
# WRONG: Platform used but not registered
def platform
  force_platform!("myplatform", {})  # Platform not in registry!
end

# CORRECT: Register before using
def platform
  Train::Platforms.name("myplatform").title("My Platform")
  force_platform!("myplatform", {})
end
```

#### 3. Mock Mode Breaks Detection

```ruby
# WRONG: Detection tries to run commands in mock mode
def detect_version
  result = run_command_via_connection("show version")  # Fails in mock!
  # ...
end

# CORRECT: Skip detection in mock mode
def detect_version
  return nil if @options&.dig(:mock)
  # ...
end
```

### Debugging Platform Detection

```ruby
def platform
  @logger.debug("Starting platform detection")
  
  version = detect_version
  @logger.debug("Detected version: #{version || 'none'}")
  
  Train::Platforms.name(PLATFORM_NAME).title("Your Platform")
  
  platform_info = {
    release: version || VERSION,
    arch: "network"
  }
  
  @logger.debug("Platform info: #{platform_info}")
  
  force_platform!(PLATFORM_NAME, platform_info)
end
```

### Platform Detection Logging

```ruby
# Enable debug logging to see detection process
export DEBUG=true
inspec detect -t yourname://device

# Example debug output:
# DEBUG -- : Starting platform detection
# DEBUG -- : Executing: show version  
# DEBUG -- : Detected version: 21.4R3-S1.6
# DEBUG -- : Platform info: {:release=>"21.4R3-S1.6", :arch=>"network"}
```

---

## Advanced Platform Patterns

### Conditional Platform Features

```ruby
def platform
  version = detect_version
  
  # Determine capabilities based on version
  capabilities = determine_capabilities(version)
  
  Train::Platforms.name(PLATFORM_NAME)
    .title("Your Platform")
    .in_family("network")
  
  force_platform!(PLATFORM_NAME, {
    release: version,
    arch: "network",
    capabilities: capabilities
  })
end

private

def determine_capabilities(version)
  caps = [:basic_commands, :file_operations]
  
  if version_at_least?(version, "2.0.0")
    caps += [:json_output, :api_access]
  end
  
  if version_at_least?(version, "3.0.0")
    caps += [:streaming, :bulk_operations]
  end
  
  caps
end
```

### Multi-Variant Platform Support

```ruby
def platform
  variant = detect_platform_variant
  
  case variant
  when :enterprise
    platform_name = "yourname-enterprise"
    platform_family = ["network", "enterprise"]
  when :cloud
    platform_name = "yourname-cloud"
    platform_family = ["network", "cloud"]
  else
    platform_name = "yourname"
    platform_family = ["network"]
  end
  
  Train::Platforms.name(platform_name)
    .title("Your Platform #{variant.to_s.capitalize}")
  
  platform_family.each { |family| Train::Platforms.name(platform_name).in_family(family) }
  
  force_platform!(platform_name, {
    release: detect_version,
    arch: "network",
    variant: variant
  })
end
```

---

## Key Takeaways

1. **Use force_platform! for dedicated plugins** - Bypasses automatic detection safely
2. **Register platforms before using** - Train must know about your platform
3. **Handle connection timing** - Detection may run before connection is ready
4. **Support mock mode** - Skip detection commands when mocking
5. **Choose appropriate families** - Determines available InSpec resources
6. **Parse versions carefully** - Handle multiple format variations
7. **Test thoroughly** - Platform detection affects all InSpec functionality

**Next**: Learn about [Testing Strategies](08-testing-strategies.md) for comprehensive plugin validation.
# Troubleshooting

Common plugin development issues, debugging techniques, and solutions to frequently encountered problems.

## Table of Contents

1. [Plugin Loading Issues](#plugin-loading-issues)
2. [Connection Problems](#connection-problems)
3. [Platform Detection Issues](#platform-detection-issues)
4. [Command Execution Problems](#command-execution-problems)
5. [Proxy and Authentication Issues](#proxy-and-authentication-issues)
6. [Testing and Development Issues](#testing-and-development-issues)
7. [Gemspec and Packaging Problems](#gemspec-and-packaging-problems)
8. [Performance and Memory Issues](#performance-and-memory-issues)

---

## Plugin Loading Issues

### Plugin Not Found by InSpec

**Symptoms:**
```bash
$ inspec detect -t yourname://device
Error: Can't find train plugin yourname. Please install it first.
```

**Causes and Solutions:**

#### 1. Plugin Not Installed
```bash
# Check if plugin is installed
inspec plugin list

# Install plugin
inspec plugin install train-yourname
```

#### 2. Incorrect Gem Name
```ruby
# Gemspec must follow naming convention
spec.name = "train-yourname"  # Correct
spec.name = "yourname-train"  # Wrong - InSpec won't find it
```

#### 3. Missing Plugin Registration
```ruby
# lib/train-yourname.rb must exist and load transport
require "train-yourname/transport"
require "train-yourname/connection"
require "train-yourname/platform"
require "train-yourname/version"
```

#### 4. Transport Not Registered with Train
```ruby
# In transport.rb - ensure plugin is registered
class Transport < Train.plugin(1)
  name "yourname"  # This must match URI scheme
  
  def connection(options = nil)
    @connection ||= Connection.new(@options.merge(options || {}))
  end
end
```

### Plugin Loads But URI Scheme Not Recognized

**Symptoms:**
```bash
$ inspec detect -t yourname://device
Error: Unsupported target URI scheme 'yourname'
```

**Solution:**
```ruby
# Verify transport name matches URI scheme
class Transport < Train.plugin(1)
  name "yourname"  # Must match yourname:// scheme
end

# Check that plugin is properly loaded
require "train-yourname"  # Should register transport
```

### Multiple Plugins with Same Name

**Symptoms:**
```bash
Warning: Multiple train plugins found for 'yourname'
```

**Solution:**
```bash
# List all installed plugins
inspec plugin list

# Uninstall conflicting versions
inspec plugin uninstall train-yourname-old

# Clean gem environment
gem cleanup train-yourname
```

---

## Connection Problems

### SSH Authentication Failures

**Symptoms:**
```bash
Train::TransportError: SSH authentication failed
```

**Debugging Steps:**

#### 1. Verify Credentials
```ruby
# Enable SSH debug logging
def establish_connection
  ssh_options = {
    logger: Logger.new(STDOUT),
    verbose: :debug  # Add this for debugging
  }
  
  @ssh_session = Net::SSH.start(@options[:host], @options[:user], ssh_options)
end
```

#### 2. Test SSH Manually
```bash
# Test SSH connection outside plugin
ssh -v admin@device.com -p 2222

# Check SSH key authentication
ssh -v -i ~/.ssh/id_rsa admin@device.com
```

#### 3. Common SSH Issues
```ruby
# Handle common authentication patterns
def ssh_connection_options
  {
    password: @options[:password],
    keys: @options[:key_files] || [],
    keys_only: @options[:keys_only] || false,
    auth_methods: determine_auth_methods,
    
    # Common compatibility settings
    verify_host_key: @options[:verify_host_key] != false,
    host_key: @options[:host_key] || "accept-new",
    
    # Timeout settings
    timeout: @options[:timeout] || 30,
    operation_timeout: @options[:operation_timeout] || 60
  }
end

private

def determine_auth_methods
  methods = []
  methods << "publickey" if @options[:key_files]
  methods << "password" if @options[:password]
  methods << "keyboard-interactive" if @options[:interactive_auth]
  
  # Fallback to common methods
  methods.empty? ? ["publickey", "password"] : methods
end
```

### Connection Timeouts

**Symptoms:**
```bash
Train::TransportError: Connection timed out
```

**Solutions:**

#### 1. Increase Timeouts
```ruby
def initialize(options)
  @options = options.dup
  @options[:timeout] ||= 60        # Connection timeout
  @options[:operation_timeout] ||= 120  # Command timeout
  
  super(@options)
end
```

#### 2. Implement Connection Retry
```ruby
def establish_connection
  retries = 0
  max_retries = @options[:max_connection_retries] || 3
  
  begin
    connect_with_timeout
  rescue Net::SSH::ConnectionTimeout => e
    retries += 1
    if retries <= max_retries
      @logger.warn("Connection timeout, retry #{retries}/#{max_retries}")
      sleep(2 ** retries)  # Exponential backoff
      retry
    else
      raise Train::TransportError, "Connection failed after #{max_retries} retries: #{e.message}"
    end
  end
end
```

### Network Connectivity Issues

**Symptoms:**
```bash
Errno::ECONNREFUSED: Connection refused
Errno::EHOSTUNREACH: No route to host
```

**Debugging:**
```ruby
def debug_network_connectivity
  host = @options[:host]
  port = @options[:port] || 22
  
  @logger.debug("Testing connectivity to #{host}:#{port}")
  
  begin
    socket = Socket.tcp(host, port, connect_timeout: 5)
    socket.close
    @logger.debug("✅ TCP connection successful")
  rescue => e
    @logger.error("❌ TCP connection failed: #{e.message}")
    
    # Additional diagnostics
    @logger.debug("Checking DNS resolution...")
    begin
      Resolv.getaddress(host)
      @logger.debug("✅ DNS resolution successful")
    rescue => dns_error
      @logger.error("❌ DNS resolution failed: #{dns_error.message}")
    end
    
    raise Train::TransportError, "Network connectivity issue: #{e.message}"
  end
end
```

---

## Platform Detection Issues

### Platform Not Detected

**Symptoms:**
```bash
inspec> os.name
=> "unknown"
```

**Debugging:**

#### 1. Check Platform Detection Logic
```ruby
def detect_platform
  @logger.debug("Starting platform detection")
  
  # Test if we can execute commands
  begin
    result = run_command("show version")
    @logger.debug("Platform detection command output: #{result.stdout}")
    
    if result.exit_status != 0
      @logger.error("Platform detection command failed: #{result.stderr}")
      return nil
    end
    
    version_info = parse_version_output(result.stdout)
    @logger.debug("Parsed version info: #{version_info}")
    
    version_info
  rescue => e
    @logger.error("Platform detection failed: #{e.message}")
    nil
  end
end
```

#### 2. Verify Platform Registration
```ruby
# In platform.rb - ensure platform is registered correctly
def platform
  force_platform!(PLATFORM_NAME, {
    release: detect_release_version || TrainPlugins::YourName::VERSION,
    arch: "network"
  })
end

private

def detect_release_version
  return "mock" if @options[:mock]
  
  begin
    result = @connection.run_command("show version")
    parse_version_from_output(result.stdout)
  rescue => e
    @logger.warn("Could not detect release version: #{e.message}")
    nil
  end
end
```

#### 3. Debug Version Parsing
```ruby
def parse_version_from_output(output)
  @logger.debug("Parsing version from: #{output}")
  
  # Try multiple patterns
  version_patterns = [
    /Version:\s+(\S+)/,
    /Software version:\s+(\S+)/,
    /Release:\s+(\S+)/,
    /\b(\d+\.\d+\S*)\b/
  ]
  
  version_patterns.each do |pattern|
    if match = output.match(pattern)
      version = match[1]
      @logger.debug("Found version using pattern #{pattern}: #{version}")
      return version
    end
  end
  
  @logger.warn("No version found in output: #{output}")
  nil
end
```

### Wrong Platform Detected

**Symptoms:**
```bash
inspec> os.name
=> "linux"  # Should be "yourname"
```

**Solution:**
```ruby
# Ensure force_platform! is called early
def platform
  # Don't rely on automatic detection - force our platform
  Train::Platforms.name(PLATFORM_NAME).title("YourSystem").in_family("network")
  
  force_platform!(PLATFORM_NAME, {
    release: detect_release_version || TrainPlugins::YourName::VERSION,
    arch: "network"
  })
end
```

---

## Command Execution Problems

### Commands Hang or Timeout

**Symptoms:**
```bash
# Command never returns
result = connection.run_command("show running-config")
```

**Solutions:**

#### 1. Implement Command Timeout
```ruby
def execute_command(cmd)
  return mock_command_result(cmd) if @options[:mock]
  
  timeout = @options[:command_timeout] || 60
  
  begin
    Timeout.timeout(timeout) do
      send_command(cmd)
    end
  rescue Timeout::Error
    @logger.error("Command timed out after #{timeout}s: #{cmd}")
    CommandResult.new("", 124, "Command timed out")
  end
end
```

#### 2. Fix Prompt Detection Issues
```ruby
# If using net-ssh-telnet or similar
def send_command(cmd)
  @logger.debug("Sending command: #{cmd}")
  
  # Clear any pending output
  clear_session_buffer
  
  # Send command with proper line ending
  @session.cmd(cmd) do |chunk|
    @logger.debug("Received chunk: #{chunk.inspect}")
    
    # Handle device-specific prompts
    if chunk.match?(/More|--More--|Press any key|continue/)
      @session.print(" ")  # Send space to continue
    end
  end
end

def clear_session_buffer
  # Read any pending output with short timeout
  begin
    Timeout.timeout(1) do
      @session.waitfor(/.*/)
    end
  rescue Timeout::Error
    # No pending output, continue
  end
end
```

### Incorrect Command Output

**Symptoms:**
```ruby
result = connection.run_command("show version")
puts result.stdout
# => Contains prompt or previous command output
```

**Solution:**
```ruby
def clean_command_output(raw_output, command)
  cleaned = raw_output.dup
  
  # Remove echo of command itself
  cleaned.gsub!(/^#{Regexp.escape(command)}\r?\n/, '')
  
  # Remove prompt patterns
  prompt_patterns = [
    /\r?\n\S+[>#%$]\s*$/,  # Standard prompts
    /\r?\n\S+\(config\)[>#%$]\s*$/,  # Config mode prompts
    /--More--.*$/,  # Pager prompts
  ]
  
  prompt_patterns.each do |pattern|
    cleaned.gsub!(pattern, '')
  end
  
  # Clean up extra whitespace
  cleaned.strip
end
```

### Character Encoding Issues

**Symptoms:**
```bash
Encoding::UndefinedConversionError: "\xE2" from ASCII-8BIT to UTF-8
```

**Solution:**
```ruby
def normalize_output_encoding(output)
  # Handle common encoding issues
  case output.encoding
  when Encoding::ASCII_8BIT
    # Try UTF-8 first, fall back to binary
    begin
      output.force_encoding('UTF-8')
      output.valid_encoding? ? output : output.force_encoding('ASCII-8BIT')
    rescue Encoding::InvalidByteSequenceError
      output.force_encoding('ASCII-8BIT')
    end
  else
    output
  end
end

def execute_command(cmd)
  raw_result = send_command(cmd)
  
  # Normalize encoding before processing
  stdout = normalize_output_encoding(raw_result.stdout)
  stderr = normalize_output_encoding(raw_result.stderr)
  
  CommandResult.new(stdout, raw_result.exit_status, stderr)
end
```

---

## Proxy and Authentication Issues

### Bastion Host Connection Failures

**Symptoms:**
```bash
Train::TransportError: Could not connect to bastion host
```

**Debugging:**
```ruby
def debug_bastion_connection
  return unless @options[:bastion_host]
  
  @logger.debug("Testing bastion connection to #{@options[:bastion_host]}")
  
  bastion_options = {
    host: @options[:bastion_host],
    port: @options[:bastion_port] || 22,
    user: @options[:bastion_user] || 'root',
    timeout: @options[:timeout] || 30
  }
  
  begin
    # Test bastion connectivity first
    bastion_session = Net::SSH.start(
      bastion_options[:host],
      bastion_options[:user],
      bastion_options.merge(logger: @logger)
    )
    
    @logger.debug("✅ Bastion connection successful")
    bastion_session.close
    
    # Then test proxied connection
    test_proxied_connection
    
  rescue => e
    @logger.error("❌ Bastion connection failed: #{e.message}")
    raise Train::TransportError, "Bastion connection error: #{e.message}"
  end
end
```

### ProxyCommand Issues

**Symptoms:**
```bash
Train::TransportError: ProxyCommand failed
```

**Solution:**
```ruby
def build_proxy_command
  if @options[:proxy_command]
    # Use custom proxy command
    @options[:proxy_command]
  elsif @options[:bastion_host]
    # Generate standard SSH ProxyCommand
    bastion_user = @options[:bastion_user] || 'root'
    bastion_port = @options[:bastion_port] || 22
    
    "ssh -o StrictHostKeyChecking=no #{bastion_user}@#{@options[:bastion_host]} -p #{bastion_port} -W %h:%p"
  else
    nil
  end
end

def test_proxy_command(proxy_cmd)
  @logger.debug("Testing ProxyCommand: #{proxy_cmd}")
  
  # Test proxy command separately
  test_cmd = proxy_cmd.gsub('%h', @options[:host]).gsub('%p', @options[:port].to_s)
  
  begin
    Open3.popen3(test_cmd) do |stdin, stdout, stderr, wait_thr|
      stdin.close
      
      # Wait briefly to see if command starts successfully
      sleep(1)
      
      if wait_thr.alive?
        @logger.debug("✅ ProxyCommand started successfully")
        Process.kill('TERM', wait_thr.pid)
      else
        error_output = stderr.read
        @logger.error("❌ ProxyCommand failed: #{error_output}")
        raise "ProxyCommand test failed: #{error_output}"
      end
    end
  rescue => e
    @logger.error("ProxyCommand test error: #{e.message}")
    raise
  end
end
```

---

## Testing and Development Issues

### Mock Mode Not Working

**Symptoms:**
```ruby
# Tests fail because mock mode isn't activated
connection = Train.create('yourname', mock: true)
result = connection.run_command('show version')
# => Tries to make real connection
```

**Solution:**
```ruby
def run_command_via_connection(cmd)
  if @options[:mock]
    return mock_command_result(cmd)
  end
  
  # Real implementation
  execute_command(cmd)
end

def mock_command_result(cmd)
  case cmd
  when /show version/
    CommandResult.new(mock_version_output, 0)
  when /show interfaces/
    CommandResult.new(mock_interfaces_output, 0)
  else
    CommandResult.new("Mock response for: #{cmd}", 0)
  end
end

def mock_version_output
  <<~OUTPUT
    Hostname: mock-device
    Model: MOCK-1000
    Version: 1.0.0-mock
    Uptime: 1 day, 2:34:56
  OUTPUT
end
```

### Test Fixtures Not Loading

**Symptoms:**
```ruby
# Fixture files not found in tests
fixture_content = File.read('test/fixtures/version_output.txt')
# => No such file or directory
```

**Solution:**
```ruby
# test/helper.rb
require 'pathname'

class TestHelper
  def self.fixture_path
    Pathname.new(__FILE__).dirname.join('fixtures')
  end
  
  def self.read_fixture(filename)
    File.read(fixture_path.join(filename))
  end
end

# In test files
def setup
  @version_output = TestHelper.read_fixture('version_output.txt')
  @mock_options = { mock: true, host: 'test-device' }
end
```

### Test Isolation Issues

**Symptoms:**
```ruby
# Tests affect each other
def test_connection_one
  @connection = create_connection(host: 'device1')
  # Test passes
end

def test_connection_two
  @connection = create_connection(host: 'device2')
  # Test fails because of state from previous test
end
```

**Solution:**
```ruby
def setup
  # Reset any class variables or singletons
  TrainPlugins::YourName::Connection.class_variable_set(:@@connection_pool, nil) if defined?(@@connection_pool)
  
  # Clear any cached platform detection
  @platform_cache = nil
  
  # Ensure clean options for each test
  @default_options = {
    mock: true,
    host: 'test-device',
    user: 'admin',
    timeout: 30
  }
end

def teardown
  # Clean up any persistent connections
  @connection&.close
  @connection = nil
end
```

---

## Gemspec and Packaging Problems

### Gem Build Warnings

**Symptoms:**
```bash
$ gem build train-yourname.gemspec
WARNING: See http://guides.rubygems.org/specification-reference/ for help
```

**Common Issues and Solutions:**

#### 1. Missing Required Fields
```ruby
# Fix missing metadata
spec.summary       = "Train plugin for YourSystem devices"
spec.description   = "Enables InSpec compliance testing for YourSystem infrastructure"
spec.homepage      = "https://github.com/yourorg/train-yourname"
spec.license       = "Apache-2.0"
spec.authors       = ["Your Name"]
spec.email         = ["your.email@example.com"]
```

#### 2. File Inclusion Issues
```ruby
# Fix file inclusion patterns
spec.files = %w{
  README.md LICENSE NOTICE CODE_OF_CONDUCT.md
  train-yourname.gemspec Gemfile Rakefile
} + Dir.glob("lib/**/*", File::FNM_DOTMATCH).reject { |f| File.directory?(f) }

# Avoid including test files in gem
spec.test_files = []  # Don't include tests
```

#### 3. Dependency Version Issues
```ruby
# Use specific version ranges
spec.add_dependency "train-core", "~> 3.12"    # Good
spec.add_dependency "train-core", ">= 3.0"     # Too broad

spec.required_ruby_version = ">= 3.0.0"        # Good
spec.required_ruby_version = ">= 2.7"          # Outdated
```

### InSpec Installation Issues

**Symptoms:**
```bash
$ inspec plugin install train-yourname-1.0.0.gem
Error: Plugin failed to load
```

**Debugging:**
```bash
# Test gem installation manually
gem install train-yourname-1.0.0.gem

# Check if plugin loads
ruby -e "require 'train-yourname'; puts 'Plugin loaded'"

# Check InSpec plugin discovery
inspec plugin list --all  # Shows all available plugins
```

---

## Performance and Memory Issues

### Memory Leaks

**Symptoms:**
```bash
# Ruby process memory grows over time during long-running tests
```

**Solutions:**

#### 1. Connection Cleanup
```ruby
def finalize
  close_connection if connected?
  clear_caches
  cleanup_temp_files
end

# Ensure cleanup on exit
at_exit { finalize }

def close_connection
  @ssh_session&.close
  @ssh_session = nil
  @connection = nil
end

def clear_caches
  @platform_cache = nil
  @command_cache&.clear
end
```

#### 2. Avoid Global State
```ruby
# Bad - global state can cause leaks
@@global_connections = {}

# Good - instance-based state
def initialize(options)
  @options = options
  @connection_pool = {}
end
```

### Slow Command Execution

**Symptoms:**
```bash
# Commands take much longer than expected
```

**Debugging:**
```ruby
def execute_command(cmd)
  start_time = Time.now
  
  result = send_command(cmd)
  
  duration = Time.now - start_time
  if duration > 5.0  # Log slow commands
    @logger.warn("Slow command (#{duration.round(2)}s): #{cmd}")
  end
  
  result
end

# Profile specific operations
def with_profiling(operation)
  start_memory = get_memory_usage
  start_time = Time.now
  
  result = yield
  
  duration = Time.now - start_time
  memory_delta = get_memory_usage - start_memory
  
  @logger.debug("#{operation}: #{duration.round(2)}s, #{memory_delta}KB")
  
  result
end

def get_memory_usage
  `ps -o rss= -p #{Process.pid}`.to_i
end
```

---

## Debug Logging Techniques

### Comprehensive Debug Mode

```ruby
def enable_debug_mode
  return unless @options[:debug] || ENV['TRAIN_DEBUG']
  
  @logger.level = Logger::DEBUG
  
  # Log all SSH activity
  @ssh_logger = Logger.new(STDOUT)
  @ssh_logger.level = Logger::DEBUG
  
  # Log method calls
  trace_method_calls
end

def trace_method_calls
  TracePoint.trace(:call) do |tp|
    if tp.defined_class.to_s.include?('TrainPlugins::YourName')
      @logger.debug("TRACE: #{tp.defined_class}##{tp.method_id}")
    end
  end
end
```

### SSH Debug Output

```ruby
def establish_connection
  ssh_options = base_ssh_options
  
  if debug_mode?
    ssh_options[:logger] = @logger
    ssh_options[:verbose] = :debug
  end
  
  @ssh_session = Net::SSH.start(@options[:host], @options[:user], ssh_options)
end
```

### Command Tracing

```ruby
def run_command_via_connection(cmd)
  if debug_mode?
    @logger.debug("EXECUTE: #{cmd}")
    @logger.debug("OPTIONS: #{@options.reject { |k,v| sensitive_option?(k) }}")
  end
  
  result = execute_command(cmd)
  
  if debug_mode?
    @logger.debug("RESULT: exit=#{result.exit_status}, stdout=#{result.stdout.bytesize} bytes")
    @logger.debug("STDOUT: #{result.stdout}") if result.stdout.length < 1000
  end
  
  result
end
```

---

## Emergency Debugging Commands

When all else fails, use these debugging techniques:

### 1. Interactive Debug Session
```ruby
# Add to your connection code
require 'pry'
binding.pry  # Drops into interactive debugger
```

### 2. Verbose Output Mode
```bash
# Enable maximum verbosity
TRAIN_DEBUG=true TRAIN_LOG_LEVEL=DEBUG inspec detect -t yourname://device
```

### 3. Manual SSH Testing
```bash
# Test SSH connectivity outside Train
ssh -vvv admin@device.com -p 2222

# Test with specific SSH options
ssh -o ProxyCommand="ssh jump.host -W %h:%p" admin@device.com
```

### 4. Strace/Dtruss System Calls
```bash
# Linux
strace -e trace=network inspec detect -t yourname://device

# macOS
dtruss -f inspec detect -t yourname://device
```

---

## Device-Specific Error Patterns

Network device plugins require handling vendor-specific error messages and command responses. Here are real patterns from production implementations:

### Cisco IOS vs Juniper Error Patterns

**Real error patterns from Train core cisco_ios_connection.rb:**

```ruby
# Cisco IOS error patterns (from built-in train-cisco-ios)
CISCO_ERROR_PATTERNS = [
  "Bad IP address",
  "Incomplete command", 
  "Invalid input detected",
  "Unrecognized host"
].freeze

# Juniper JunOS error patterns (from our train-juniper)
JUNOS_ERROR_PATTERNS = [
  /^error:/i,
  /syntax error/i,
  /invalid command/i,
  /unknown command/i,
  /missing argument/i
].freeze
```

**Key Differences:**
- **Cisco**: Uses specific string messages like "Invalid input detected"
- **Juniper**: Uses more general patterns like "unknown command"
- **Error detection**: Cisco checks exact strings, Juniper uses regex patterns

### Prompt Pattern Differences

```ruby
# Cisco IOS prompt handling (from cisco_ios_connection.rb)
def cisco_prompt_pattern
  /\S+[>#]\r\n.*$/
end

# Juniper JunOS prompt handling (from our train-juniper) 
def juniper_prompt_patterns
  @cli_prompt = /[%>$#]\s*$/
  @config_prompt = /[%#]\s*$/
end
```

**Pattern Analysis:**
- **Cisco**: Expects hostname followed by `>` (user) or `#` (privileged) mode
- **Juniper**: More flexible pattern matching various prompt styles
- **Mode detection**: Both need to handle different privilege levels

### Command Error Detection

```ruby
# Cisco error detection pattern
def cisco_command_failed?(output)
  CISCO_ERROR_PATTERNS.any? { |pattern| output.include?(pattern) }
end

# Juniper error detection pattern  
def juniper_command_failed?(output)
  JUNOS_ERROR_PATTERNS.any? { |pattern| output.match?(pattern) }
end

# Usage in command execution
def run_command_via_connection(cmd)
  result = execute_command(cmd)
  
  if cisco_command_failed?(result.stdout)
    CommandResult.new(result.stdout, 1, "Command failed: #{cmd}")
  else
    result
  end
end
```

### Authentication Error Variations

```ruby
# Network device authentication patterns
def handle_device_authentication_error(error)
  case error.message
  when /Authentication failed|Login failed/
    # Both Cisco and Juniper
    "SSH authentication failed. Check username and password."
  when /Access denied/
    # Common in Cisco IOS
    "Access denied. User may not have sufficient privileges."
  when /Permission denied/
    # Common in Juniper JunOS
    "Permission denied. Check user permissions and SSH configuration."
  when /Enable password required/
    # Cisco-specific privilege escalation
    "Enable password required for privileged mode access."
  else
    "Device authentication error: #{error.message}"
  end
end
```

### Platform-Specific Debugging

```ruby
# Cisco IOS debugging
def debug_cisco_connection
  @logger.debug("Cisco IOS connection diagnostics:")
  @logger.debug("Current prompt: #{@current_prompt}")
  @logger.debug("Privilege level: #{detect_privilege_level}")
  @logger.debug("Enable mode: #{in_enable_mode?}")
end

# Juniper JunOS debugging  
def debug_juniper_connection
  @logger.debug("Juniper JunOS connection diagnostics:")
  @logger.debug("CLI prompt pattern: #{@cli_prompt}")
  @logger.debug("Config mode: #{in_config_mode?}")
  @logger.debug("Session type: #{@session_type}")
end
```

### Device Command Differences

```ruby
# Platform-specific command mapping
def normalize_command_for_device(cmd)
  case @platform_name
  when "cisco-ios"
    cisco_command_adaptations(cmd)
  when "juniper"
    juniper_command_adaptations(cmd)
  else
    cmd
  end
end

private

def cisco_command_adaptations(cmd)
  case cmd
  when /^show version$/
    "show version"  # Standard
  when /^show config$/
    "show running-config"  # Cisco-specific
  when /^show interfaces$/
    "show ip interface brief"  # Cisco summary format
  else
    cmd
  end
end

def juniper_command_adaptations(cmd)
  case cmd  
  when /^show version$/
    "show version"  # Standard
  when /^show config$/
    "show configuration"  # Juniper-specific
  when /^show interfaces$/
    "show interfaces terse"  # Juniper summary format
  else
    cmd
  end
end
```

---

## Key Troubleshooting Principles

1. **Start Simple** - Test basic SSH connectivity before debugging Train plugin
2. **Enable Logging** - Use debug mode and verbose SSH logging liberally
3. **Isolate Issues** - Test each component (SSH, commands, platform detection) separately
4. **Check Community** - Many issues have been solved by other plugin developers
5. **Document Solutions** - Keep notes on fixes for future reference
6. **Test Edge Cases** - Network timeouts, authentication failures, encoding issues
7. **Verify Environment** - Ruby version, gem dependencies, SSH client configuration

**Next**: Learn about [Real-World Examples](12-real-world-examples.md) of complete plugin implementations.
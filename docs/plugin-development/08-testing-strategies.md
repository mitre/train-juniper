# Testing Strategies

Comprehensive testing approaches for Train plugins including unit tests, integration tests, and mock mode implementation.

## Table of Contents

1. [Testing Philosophy](#testing-philosophy)
2. [Test Structure and Organization](#test-structure-and-organization)
3. [Unit Testing](#unit-testing)
4. [Integration Testing](#integration-testing)
5. [Mock Mode Implementation](#mock-mode-implementation)
6. [Real Device Testing](#real-device-testing)
7. [CI/CD Integration](#cicd-integration)
8. [Testing Best Practices](#testing-best-practices)

---

## Testing Philosophy

### Why Comprehensive Testing Matters

Train plugins bridge InSpec with target systems, making them critical infrastructure components. Poor testing leads to:

- **Production failures** during compliance scans
- **Credential exposure** through error messages  
- **Connection issues** in enterprise environments
- **Platform detection failures** breaking InSpec workflows

### Testing Pyramid for Train Plugins

```
    /\
   /  \     E2E Tests (Few)
  /____\    - Real device integration
 /      \   - Full workflow validation
/________\  
           Integration Tests (Some)
          - URI parsing, proxy setup
         - Mock device scenarios
        
        Unit Tests (Many) 
       - Transport registration
      - Connection initialization
     - Command result parsing
```

### Test Categories

1. **Unit Tests** - Fast, isolated, no network dependencies
2. **Integration Tests** - Component interaction, mock scenarios
3. **Functional Tests** - End-to-end with real devices (optional)
4. **Performance Tests** - Connection speed, command throughput

---

## Test Structure and Organization

### Standard Directory Layout

```
test/
├── helper.rb                     # Test setup and utilities
├── unit/
│   ├── transport_test.rb         # Plugin registration tests
│   ├── connection_test.rb        # Connection logic tests
│   ├── platform_test.rb          # Platform detection tests
│   └── version_test.rb           # Version handling tests
├── integration/
│   ├── proxy_connection_test.rb  # Proxy/bastion scenarios
│   ├── uri_parsing_test.rb       # Connection string parsing
│   └── error_handling_test.rb    # Error scenarios
└── functional/
    ├── real_device_test.rb       # Optional real device tests
    └── performance_test.rb       # Optional performance tests
```

### Test Helper Setup

```ruby
# test/helper.rb
require "minitest/autorun"
require "minitest/spec"
require "simplecov" if ENV["COVERAGE"]

# Start code coverage if enabled
if ENV["COVERAGE"]
  SimpleCov.start do
    add_filter "/test/"
    minimum_coverage 85
  end
end

# Load the plugin
require "train"
require_relative "../lib/train-yourname"

# Test utilities
module TestHelpers
  def mock_options
    {
      mock: true,
      host: "test.example.com",
      user: "testuser",
      password: "testpass",
      port: 22,
      timeout: 30
    }
  end

  def create_mock_connection(options = {})
    opts = mock_options.merge(options)
    TrainPlugins::YourName::Connection.new(opts)
  end

  def create_mock_transport(options = {})
    opts = mock_options.merge(options)
    transport = TrainPlugins::YourName::Transport.new
    transport.instance_variable_set(:@options, opts)
    transport
  end

  def real_device_available?
    ENV["REAL_DEVICE_HOST"] && ENV["REAL_DEVICE_USER"]
  end

  def real_device_options
    {
      host: ENV["REAL_DEVICE_HOST"],
      user: ENV["REAL_DEVICE_USER"],
      password: ENV["REAL_DEVICE_PASSWORD"],
      port: ENV["REAL_DEVICE_PORT"]&.to_i || 22,
      timeout: ENV["REAL_DEVICE_TIMEOUT"]&.to_i || 30
    }
  end
end

# Include helpers in all tests
class Minitest::Spec
  include TestHelpers
end
```

---

## Unit Testing

### Transport Registration Tests

```ruby
# test/unit/transport_test.rb
require_relative "../helper"
require "train-yourname/transport"

describe TrainPlugins::YourName::Transport do
  let(:plugin_class) { TrainPlugins::YourName::Transport }

  it "should be registered with Train without train- prefix" do
    _(Train::Plugins.registry.keys).must_include("yourname")
    _(Train::Plugins.registry.keys).wont_include("train-yourname")
  end

  it "should inherit from Train plugin base" do
    _((plugin_class < Train.plugin(1))).must_equal(true)
  end

  it "should provide connection method" do
    _(plugin_class.instance_methods(false)).must_include(:connection)
  end

  describe "transport options" do
    let(:transport) { plugin_class.new }

    it "should define required options" do
      required_options = [:host, :user]
      required_options.each do |option|
        _(transport.class.default_options.keys).must_include(option)
      end
    end

    it "should define proxy options" do
      proxy_options = [:bastion_host, :bastion_user, :proxy_command]
      proxy_options.each do |option|
        _(transport.class.default_options.keys).must_include(option)
      end
    end

    it "should have correct default values" do
      defaults = transport.class.default_options
      _(defaults[:port][:default]).must_equal(22)
      _(defaults[:bastion_user][:default]).must_equal("root")
      _(defaults[:timeout][:default]).must_equal(30)
    end
  end

  describe "connection creation" do
    it "should create connection with valid options" do
      transport = create_mock_transport
      connection = transport.connection
      _(connection).must_be_instance_of(TrainPlugins::YourName::Connection)
    end

    it "should cache connection instances" do
      transport = create_mock_transport
      connection1 = transport.connection
      connection2 = transport.connection
      _(connection1).must_be_same_as(connection2)
    end
  end
end
```

### Connection Tests

```ruby
# test/unit/connection_test.rb
require_relative "../helper"
require "train-yourname/connection"

describe TrainPlugins::YourName::Connection do
  let(:connection_class) { TrainPlugins::YourName::Connection }

  it "should inherit from BaseConnection" do
    _((connection_class < Train::Plugins::Transport::BaseConnection)).must_equal(true)
  end

  describe "required methods" do
    %i{run_command_via_connection file_via_connection}.each do |method_name|
      it "should provide #{method_name} method" do
        _(connection_class.instance_methods(false)).must_include(method_name)
      end
    end
  end

  describe "initialization" do
    it "should accept valid options" do
      connection = create_mock_connection
      _(connection).must_be_instance_of(connection_class)
    end

    it "should convert string options to correct types" do
      connection = create_mock_connection({
        port: "2222",      # String from URI
        timeout: "60",     # String from URI
        ssl: "true"        # String from URI
      })

      options = connection.instance_variable_get(:@options)
      _(options[:port]).must_equal(2222)      # Integer
      _(options[:timeout]).must_equal(60)     # Integer
      _(options[:ssl]).must_equal(true)       # Boolean
    end

    it "should support environment variables" do
      ENV["YOUR_HOST"] = "env.example.com"
      ENV["YOUR_USER"] = "envuser"

      connection = create_mock_connection({ host: nil, user: nil })
      options = connection.instance_variable_get(:@options)

      _(options[:host]).must_equal("env.example.com")
      _(options[:user]).must_equal("envuser")

      # Cleanup
      ENV.delete("YOUR_HOST")
      ENV.delete("YOUR_USER")
    end

    it "should prioritize explicit options over environment" do
      ENV["YOUR_HOST"] = "env.example.com"

      connection = create_mock_connection({ host: "explicit.example.com" })
      options = connection.instance_variable_get(:@options)

      _(options[:host]).must_equal("explicit.example.com")

      # Cleanup
      ENV.delete("YOUR_HOST")
    end
  end

  describe "mock mode" do
    let(:connection) { create_mock_connection }

    it "should execute mock commands" do
      result = connection.run_command("show version")
      _(result.exit_status).must_equal(0)
      _(result.stdout).wont_be_empty
    end

    it "should handle different mock commands" do
      test_commands = {
        "show version" => /version/i,
        "show config" => /config/i,
        "show status" => /status/i
      }

      test_commands.each do |cmd, pattern|
        result = connection.run_command(cmd)
        _(result.exit_status).must_equal(0)
        _(result.stdout).must_match(pattern)
      end
    end

    it "should handle unknown commands gracefully" do
      result = connection.run_command("invalid command")
      _(result.exit_status).must_equal(1)
      _(result.stderr).must_match(/unknown|invalid/i)
    end
  end

  describe "file operations" do
    let(:connection) { create_mock_connection }

    it "should create file objects" do
      file = connection.file("/test/path")
      _(file).must_respond_to(:content)
      _(file).must_respond_to(:exist?)
    end

    it "should handle different file paths" do
      paths = ["/config/interfaces", "/status/system", "/logs/security"]

      paths.each do |path|
        file = connection.file(path)
        _(file).must_respond_to(:content)
      end
    end
  end
end
```

### Platform Detection Tests

```ruby
# test/unit/platform_test.rb
require_relative "../helper"
require "train-yourname/platform"

describe TrainPlugins::YourName::Platform do
  let(:connection) { create_mock_connection }

  it "should use force_platform for dedicated plugins" do
    platform = connection.platform

    _(platform[:name]).must_equal("yourname")
    _(platform[:families]).must_include("network")
  end

  it "should include plugin version as fallback release" do
    platform = connection.platform
    
    _(platform[:release]).wont_be_nil
    _(platform[:release]).wont_be_empty
  end

  describe "version detection" do
    it "should parse version from command output" do
      # Mock the version command
      def connection.run_command_via_connection(cmd)
        return CommandResult.new("Version: 1.2.3-beta\nBuild: 456", 0) if cmd == "show version"
        CommandResult.new("", 1)
      end

      version = connection.send(:detect_version)
      _(version).must_equal("1.2.3-beta")
    end

    it "should handle multiple version formats" do
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

    it "should return nil for unparseable output" do
      invalid_outputs = ["", "No version info", "Error: command failed"]

      invalid_outputs.each do |output|
        version = connection.send(:extract_version_from_output, output)
        _(version).must_be_nil
      end
    end
  end
end
```

---

## Integration Testing

### URI Parsing Tests

```ruby
# test/integration/uri_parsing_test.rb
require_relative "../helper"

describe "URI Parsing Integration" do
  
  it "should parse basic URI components" do
    config = Train.target_config(target: "yourname://user@host:123")
    
    _(config[:backend]).must_equal("yourname")
    _(config[:user]).must_equal("user")
    _(config[:host]).must_equal("host")
    _(config[:port]).must_equal("123")  # String from URI
  end

  it "should parse query parameters" do
    uri = "yourname://user@host?timeout=60&ssl=true"
    config = Train.target_config(target: uri)
    
    _(config[:timeout]).must_equal("60")
    _(config[:ssl]).must_equal("true")
  end

  it "should handle URL encoding in parameters" do
    proxy_cmd = "ssh%20jump.host%20-W%20%25h:%25p"
    uri = "yourname://user@host?proxy_command=#{proxy_cmd}"
    config = Train.target_config(target: uri)
    
    _(config[:proxy_command]).must_equal("ssh jump.host -W %h:%p")
  end

  it "should create working connections from parsed URIs" do
    uri = "yourname://admin@device.local?timeout=30"
    config = Train.target_config(target: uri)
    config[:mock] = true

    transport = Train.create(config[:backend], config)
    connection = transport.connection

    _(connection).must_be_instance_of(TrainPlugins::YourName::Connection)
    
    # Test that connection works
    result = connection.run_command("show version")
    _(result.exit_status).must_equal(0)
  end
end
```

### Proxy Configuration Tests

```ruby
# test/integration/proxy_connection_test.rb
require_relative "../helper"

describe "Proxy Connection Integration" do

  describe "bastion host configuration" do
    let(:bastion_options) do
      mock_options.merge({
        bastion_host: "jump.example.com",
        bastion_user: "netadmin",
        bastion_port: 2222
      })
    end

    it "should accept bastion host options" do
      connection = create_mock_connection(bastion_options)
      options = connection.instance_variable_get(:@options)

      _(options[:bastion_host]).must_equal("jump.example.com")
      _(options[:bastion_user]).must_equal("netadmin")
      _(options[:bastion_port]).must_equal(2222)
    end

    it "should generate correct bastion proxy command" do
      connection = create_mock_connection(bastion_options)
      proxy_command = connection.send(:generate_bastion_proxy_command)

      _(proxy_command).must_match(/ssh/)
      _(proxy_command).must_match(/netadmin@jump.example.com/)
      _(proxy_command).must_match(/-p 2222/)
      _(proxy_command).must_match(/-W %h:%p/)
    end
  end

  describe "custom proxy command" do
    let(:proxy_options) do
      mock_options.merge({
        proxy_command: "ssh jump.host -W %h:%p"
      })
    end

    it "should accept custom proxy command" do
      connection = create_mock_connection(proxy_options)
      options = connection.instance_variable_get(:@options)

      _(options[:proxy_command]).must_equal("ssh jump.host -W %h:%p")
    end
  end

  describe "proxy option validation" do
    it "should reject both bastion_host and proxy_command" do
      invalid_options = mock_options.merge({
        bastion_host: "jump.host",
        proxy_command: "ssh proxy -W %h:%p"
      })

      _(-> { create_mock_connection(invalid_options) }).must_raise(Train::ClientError)
    end
  end

  describe "Train.create integration" do
    it "should work with bastion host via Train.create" do
      transport = Train.create("yourname", {
        host: "internal.device",
        user: "admin",
        bastion_host: "jump.corp.com",
        mock: true
      })

      connection = transport.connection
      result = connection.run_command("show version")
      _(result.exit_status).must_equal(0)
    end
  end
end
```

---

## Mock Mode Implementation

### Comprehensive Mock Strategy

```ruby
# In connection.rb
def run_command_via_connection(cmd)
  return mock_command_result(cmd) if @options[:mock]
  
  # Real implementation
  execute_real_command(cmd)
end

private

def mock_command_result(cmd)
  case cmd
  when /show version/i
    mock_version_command
  when /show config(?:\s+(.+))?/i
    mock_config_command($1)
  when /show status(?:\s+(.+))?/i
    mock_status_command($1)
  when /show interfaces?(?:\s+(.+))?/i
    mock_interface_command($1)
  when /invalid|error/i
    CommandResult.new("", 1, "Invalid command")
  else
    mock_generic_command(cmd)
  end
end

def mock_version_command
  output = <<~OUTPUT
    Hostname: mock-device
    Model: MockDevice-1000
    Version: #{TrainPlugins::YourName::VERSION}
    Build: #{Time.now.strftime('%Y%m%d')}
    Uptime: 5 days, 3 hours, 22 minutes
  OUTPUT
  
  CommandResult.new(output, 0)
end

def mock_config_command(section)
  case section
  when "interfaces", "interface"
    mock_interface_config
  when "system"
    mock_system_config
  when nil, ""
    mock_full_config
  else
    CommandResult.new("Configuration section: #{section}\n  # No configuration", 0)
  end
end

def mock_interface_config
  output = <<~OUTPUT
    interface ethernet-1/0/1
        description "Connection to uplink"
        ip address 192.168.1.1/24
        status enabled
    interface ethernet-1/0/2
        description "Connection to server"
        ip address 10.0.1.1/24
        status disabled
  OUTPUT
  
  CommandResult.new(output, 0)
end
```

### Stateful Mock Implementation

```ruby
class MockDeviceState
  def initialize
    @interfaces = {
      "eth0" => { 
        ip: "192.168.1.100/24", 
        status: "up", 
        description: "Management interface" 
      },
      "eth1" => { 
        ip: "10.0.1.100/24", 
        status: "down", 
        description: "Data interface" 
      }
    }
    @system_info = {
      hostname: "mock-device-#{rand(1000)}",
      uptime: Time.now - (rand(30) * 24 * 60 * 60)  # Random uptime up to 30 days
    }
  end

  def interface_info(name = nil)
    return @interfaces if name.nil?
    @interfaces[name] || { status: "not found" }
  end

  def set_interface_status(name, status)
    @interfaces[name][:status] = status if @interfaces[name]
  end

  def system_uptime
    seconds = Time.now - @system_info[:uptime]
    days = (seconds / 86400).to_i
    hours = ((seconds % 86400) / 3600).to_i
    "#{days} days, #{hours} hours"
  end
end

def mock_command_result(cmd)
  @mock_state ||= MockDeviceState.new

  case cmd
  when /show interface\s+(\w+)/
    interface_name = $1
    info = @mock_state.interface_info(interface_name)
    output = "Interface #{interface_name}: #{info[:status]} (#{info[:ip]})"
    CommandResult.new(output, 0)
  when /show uptime/
    CommandResult.new(@mock_state.system_uptime, 0)
  when /set interface (\w+) (\w+)/
    interface_name, status = $1, $2
    @mock_state.set_interface_status(interface_name, status)
    CommandResult.new("Interface #{interface_name} set to #{status}", 0)
  else
    mock_generic_command(cmd)
  end
end
```

---

## Real Device Testing

### Optional Real Device Tests

```ruby
# test/functional/real_device_test.rb
require_relative "../helper"

describe "Real Device Integration", :if => real_device_available? do
  let(:connection) { TrainPlugins::YourName::Connection.new(real_device_options) }

  it "should connect to real device" do
    _(connection).must_respond_to(:run_command)
    _(connection).must_respond_to(:file)
  end

  it "should execute version command on real device" do
    result = connection.run_command("show version")
    
    _(result.exit_status).must_equal(0)
    _(result.stdout).wont_be_empty
    _(result.stdout).must_match(/version/i)
  end

  it "should detect platform correctly" do
    platform = connection.platform
    
    _(platform[:name]).must_equal("yourname")
    _(platform[:families]).must_include("network")
    _(platform[:release]).wont_be_nil
  end

  it "should handle file operations" do
    file = connection.file("/config/system")
    
    # File may or may not exist, but should not error
    _(-> { file.content }).wont_raise
    _(-> { file.exist? }).wont_raise
  end
end
```

### Environment-Based Test Configuration

```bash
# .env.example (copy to .env for real device testing)
REAL_DEVICE_HOST=device.example.com
REAL_DEVICE_USER=admin
REAL_DEVICE_PASSWORD=secret123
REAL_DEVICE_PORT=22
REAL_DEVICE_TIMEOUT=30

# Proxy testing
REAL_DEVICE_BASTION_HOST=jump.example.com
REAL_DEVICE_BASTION_USER=netops
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/test.yml
name: Test train-yourname

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        ruby-version: ['3.0', '3.1', '3.2']

    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Ruby ${{ matrix.ruby-version }}
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: ${{ matrix.ruby-version }}
        bundler-cache: true
    
    - name: Run unit tests
      run: bundle exec rake test:unit
    
    - name: Run integration tests  
      run: bundle exec rake test:integration
    
    - name: Run linting
      run: bundle exec rake lint
    
    - name: Generate coverage report
      run: |
        export COVERAGE=true
        bundle exec rake test
    
    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage/coverage.xml
```

### Rakefile Test Tasks

```ruby
# Rakefile
require "rake/testtask"

# Default test task (unit + integration)
Rake::TestTask.new(:test) do |t|
  t.libs.push "lib"
  t.test_files = FileList[
    "test/unit/*_test.rb",
    "test/integration/*_test.rb"
  ]
  t.verbose = true
  t.warning = false
end

# Unit tests only (fast)
Rake::TestTask.new("test:unit") do |t|
  t.libs.push "lib"
  t.test_files = FileList["test/unit/*_test.rb"]
  t.verbose = true
end

# Integration tests only
Rake::TestTask.new("test:integration") do |t|
  t.libs.push "lib"
  t.test_files = FileList["test/integration/*_test.rb"]
  t.verbose = true
end

# Real device tests (optional)
Rake::TestTask.new("test:real") do |t|
  t.libs.push "lib"
  t.test_files = FileList["test/functional/*_test.rb"]
  t.verbose = true
end

# All tests including real devices
task "test:all" => ["test", "test:real"]
```

---

## Testing Best Practices

### 1. Test Coverage Goals

- **Unit Tests**: 90%+ coverage of core logic
- **Integration Tests**: All URI patterns and proxy scenarios
- **Error Handling**: All error paths and edge cases
- **Mock Mode**: 100% coverage of mock functionality

### 2. Test Naming Conventions

```ruby
# Good test names
it "should parse version from show version output"
it "should reject conflicting proxy options"
it "should generate correct bastion proxy command"
it "should handle connection timeout gracefully"

# Poor test names  
it "should work"
it "tests version stuff"
it "proxy test"
```

### 3. Test Organization

```ruby
describe "Connection" do
  describe "initialization" do
    # Initialization tests
  end
  
  describe "command execution" do
    # Command tests
  end
  
  describe "error handling" do
    # Error scenario tests
  end
end
```

### 4. Assertion Patterns

```ruby
# Use specific assertions
_(result.exit_status).must_equal(0)
_(result.stdout).must_match(/expected pattern/)
_(connection).must_be_instance_of(ExpectedClass)

# Avoid generic assertions
_(result).must_be(:truthy)  # Too vague
_(something).wont_be_nil    # Not specific enough
```

### 5. Test Data Management

```ruby
# Use constants for test data
MOCK_VERSION_OUTPUT = <<~OUTPUT
  Version: 1.2.3
  Build: 456
OUTPUT

MOCK_CONFIG_OUTPUT = <<~OUTPUT
  interface eth0
    ip 192.168.1.1/24
OUTPUT

# Use factories for complex objects
def create_mock_connection_with_proxy(proxy_type = :bastion)
  case proxy_type
  when :bastion
    create_mock_connection(bastion_host: "jump.host")
  when :proxy_command
    create_mock_connection(proxy_command: "ssh jump -W %h:%p")
  end
end
```

---

## Key Takeaways

1. **Test pyramid approach** - Many unit tests, some integration tests, few E2E tests
2. **Mock mode is essential** - Enables rapid development and CI/CD
3. **Test URI parsing thoroughly** - Critical for user experience
4. **Cover all proxy scenarios** - Enterprise environments depend on this
5. **Use real devices sparingly** - For final validation, not regular testing
6. **Automate with CI/CD** - Catch regressions early
7. **Maintain high coverage** - Train plugins are critical infrastructure

**Next**: Learn about [Packaging and Publishing](09-packaging-publishing.md) your plugin.
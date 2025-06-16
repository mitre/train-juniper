# The Complete Guide to Writing Train Plugins

**⚠️ DEPRECATED: This document has been superseded by the modular Plugin Development Guide**

**New Location**: See `docs/plugin-development/` for the updated, focused guide structure.

**Migration Status**: ✅ **COMPLETE** - All practical content has been migrated to focused modules with significant enhancements including community plugin research, comprehensive URI patterns, and expanded troubleshooting guidance.

**Quick Start**: Read `docs/plugin-development/README.md` for the new guide structure.

**Coverage Analysis**: See `docs/plugin-development/COVERAGE-ANALYSIS.md` for detailed comparison.

---

*Original 1966-line comprehensive guide based on developing train-juniper for Juniper Networks JunOS devices*

**⚠️ This document is now obsolete. New readers should use the modular guide which provides 130% of the value (complete coverage + enhancements) in a more learnable format.**

## Table of Contents

1. [What is Train and Why Plugins Matter](#what-is-train-and-why-plugins-matter)
2. [Understanding the Train Ecosystem](#understanding-the-train-ecosystem)
3. [Plugin Architecture Deep Dive](#plugin-architecture-deep-dive)
4. [Setting Up Your Development Environment](#setting-up-your-development-environment)
5. [Step-by-Step Plugin Implementation](#step-by-step-plugin-implementation)
6. [Connection URI Design and Proxy Support](#connection-uri-design-and-proxy-support)
7. [Testing Your Plugin](#testing-your-plugin)
8. [Platform Detection Strategies](#platform-detection-strategies)
9. [Packaging and Publishing](#packaging-and-publishing)
10. [Advanced Patterns and Best Practices](#advanced-patterns-and-best-practices)
11. [Troubleshooting Common Issues](#troubleshooting-common-issues)
12. [Real-World Examples](#real-world-examples)
13. [Future Improvements and TODOs](#future-improvements-and-todos)

---

## What is Train and Why Plugins Matter

### Train's Role in the InSpec Ecosystem

**Train** is the connectivity layer that sits between InSpec (the compliance testing tool) and target systems. Think of it as the "driver" that enables InSpec to talk to different types of systems:

```
InSpec Test → Train Plugin → Target System
     ↓              ↓             ↓
"Check SSH"  → SSH Connection → Linux Server
"Check API"  → REST Transport → Cloud API
"Check DB"   → DB Connection  → Database
```

### Why Write a Train Plugin?

- **Enable InSpec for new platforms** (network devices, IoT, proprietary systems)
- **Provide standardized access** to APIs, services, or protocols
- **Abstract complex connectivity** behind simple Train interface
- **Leverage InSpec's testing framework** for any connected system

### Key Concept: Plugin vs Transport

- **Plugin**: The entire gem package (train-yourname)
- **Transport**: The connectivity implementation within the plugin
- **Connection**: The active session/client instance
- **Platform**: The target system identification

---

## Understanding the Train Ecosystem

### How Train Plugins are Discovered

1. **Gem Installation**: `inspec plugin install train-yourname`
2. **Plugin Registration**: Train scans for gems matching `train-*`
3. **Auto-loading**: When `inspec -t yourname://` is used
4. **Class Loading**: Train loads your plugin's entry point

### Train Plugin API Versions

**IMPORTANT**: Only Train Plugin API v1 exists, despite what documentation might suggest.

```ruby
# CORRECT - Only version available
class Transport < Train.plugin(1)

# WRONG - Version 2 doesn't exist
class Transport < Train.plugin(2)  # Will fail!
```

### The Train Registry System

When your plugin loads, it registers with Train's plugin registry:

```ruby
# Your plugin registers as:
Train::Plugins.registry["yourname"] = YourTransportClass

# NOT as:
Train::Plugins.registry["train-yourname"]  # Wrong!
```

**Critical Rule**: Plugin gem is named `train-yourname`, but registers as `yourname`.

---

## Plugin Architecture Deep Dive

### Required File Structure

Train plugins MUST follow this exact 4-file structure:

```
lib/
├── train-yourname.rb              # Entry point (REQUIRED)
└── train-yourname/
    ├── version.rb                 # Version constant (REQUIRED)
    ├── transport.rb               # Plugin registration (REQUIRED)
    ├── connection.rb              # Core implementation (REQUIRED)
    └── platform.rb                # Platform detection (REQUIRED)
```

**Why this structure?**
- `train-yourname.rb`: InSpec loads this first when plugin is needed
- `version.rb`: Gem version management, loaded by gemspec
- `transport.rb`: Registers plugin with Train's plugin system
- `connection.rb`: All the actual work happens here
- `platform.rb`: Tells Train what type of system you connect to

### 1. Entry Point File (`lib/train-yourname.rb`)

This file is loaded by InSpec when your plugin is needed:

```ruby
# lib/train-yourname.rb

# Setup load path for development
libdir = __dir__
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

# Load version first (needed by gemspec)
require "train-yourname/version"

# Load components in dependency order
require "train-yourname/transport"    # Registers plugin
require "train-yourname/platform"    # Platform detection
require "train-yourname/connection"  # Implementation
```

**Key Points**:
- Keep this file simple - just requires
- Order matters: version → transport → platform → connection
- Load path setup helps during development

### 2. Version File (`lib/train-yourname/version.rb`)

```ruby
# lib/train-yourname/version.rb

module TrainPlugins
  module YourName  # CamelCase version of your plugin name
    VERSION = "0.1.0".freeze
  end
end
```

**Naming Convention**:
- Plugin name: `train-my-plugin` → Module: `TrainPlugins::MyPlugin`
- Kebab-case → CamelCase conversion
- Always use `.freeze` for VERSION constant

### 3. Transport Class (`lib/train-yourname/transport.rb`)

This registers your plugin with Train:

```ruby
# lib/train-yourname/transport.rb

require "train-yourname/connection"

module TrainPlugins
  module YourName
    class Transport < Train.plugin(1)
      # REQUIRED: Name without 'train-' prefix
      name "yourname"

      # REQUIRED: Must return connection instance
      def connection(instance_opts = nil)
        # Merge any instance options with global options
        opts = merge_options(options, instance_opts || {})
        
        # Return connection instance
        Connection.new(opts)
      end
    end
  end
end
```

**Critical Requirements**:
- **Must inherit from `Train.plugin(1)`**
- **Must implement `name` DSL** (without train- prefix)
- **Must implement `connection` method**
- Connection method must return BaseConnection subclass

### 4. Connection Class (`lib/train-yourname/connection.rb`)

This is where all the real work happens:

```ruby
# lib/train-yourname/connection.rb

require "train"
require "train-yourname/platform"

module TrainPlugins
  module YourName
    class Connection < Train::Plugins::Transport::BaseConnection
      # Include platform detection
      include TrainPlugins::YourName::Platform

      def initialize(options)
        # Process options, set defaults
        @options = options.dup
        @options[:host] ||= ENV['YOUR_HOST']
        @options[:timeout] ||= 30
        
        # Call parent constructor
        super(options)
        
        # Initialize your connection
        connect unless @options[:mock]
      end

      # REQUIRED: Command execution
      def run_command_via_connection(cmd)
        # Return object with: stdout, stderr, exit_status
        # See "Connection Implementation Patterns" below
      end

      # REQUIRED: File operations  
      def file_via_connection(path)
        # Return Train::File compatible object
        # See "File Implementation Patterns" below
      end

      private

      def connect
        # Establish connection to target system
      end
    end
  end
end
```

### 5. Platform Class (`lib/train-yourname/platform.rb`)

Platform detection tells Train what type of system you connect to:

```ruby
# lib/train-yourname/platform.rb

module TrainPlugins::YourName
  module Platform
    PLATFORM_NAME = "yourname".freeze
    
    def platform
      # Register platform with Train
      Train::Platforms.name(PLATFORM_NAME)
        .title("Your Platform Name")
        .in_family("your-family")  # os, network, cloud, api
      
      # Bypass Train's detection - use force_platform!
      force_platform!(PLATFORM_NAME, {
        release: detect_version || TrainPlugins::YourName::VERSION,
        arch: "your-architecture"
      })
    end

    private

    def detect_version
      # Safely detect target system version
      # Only run after connection is established
    end
  end
end
```

---

## Setting Up Your Development Environment

### Prerequisites

```bash
# Required tools
ruby >= 3.1.0
bundler >= 2.0
git

# For testing (recommended)
inspec >= 4.0
```

### Project Setup

```bash
# 1. Create plugin directory
mkdir train-yourname
cd train-yourname

# 2. Create basic structure
mkdir -p lib/train-yourname test/{unit,functional} docs

# 3. Initialize git
git init
```

### Essential Files

**Gemfile**:
```ruby
source "https://rubygems.org"

# Use train-core for lighter dependency footprint
gem "train-core", "~> 3.12"

# Add your specific dependencies
gem "your-sdk", "~> 1.0"

# Bundler should refer to the gemspec for dependencies
gemspec

group :development do
  gem "bundler"
  gem "rake"
  gem "minitest"
  gem "rubocop"
end
```

**Rakefile**:
```ruby
require "rake/testtask"

# Test task
Rake::TestTask.new do |t|
  t.libs.push "lib"
  t.test_files = FileList[
    "test/unit/*_test.rb",
    "test/functional/*_test.rb"
  ]
  t.verbose = true
  t.warning = false
end

# Lint task
require "rubocop/rake_task"
RuboCop::RakeTask.new(:lint)

# Default task
task default: :test
```

**Gemspec Template**:
```ruby
lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "train-yourname/version"

Gem::Specification.new do |spec|
  spec.name          = "train-yourname"
  spec.version       = TrainPlugins::YourName::VERSION
  spec.authors       = ["Your Name"]
  spec.email         = ["your@email.com"]
  spec.summary       = "Train transport for Your System"
  spec.description   = "Detailed description..."
  spec.homepage      = "https://github.com/yourorg/train-yourname"
  spec.license       = "Apache-2.0"
  
  spec.files = %w{
    README.md train-yourname.gemspec LICENSE
  } + Dir.glob("lib/**/*", File::FNM_DOTMATCH).reject { |f| File.directory?(f) }
  
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 3.1.0"
  
  # Dependencies
  spec.add_dependency "train-core", "~> 3.12"
end
```

---

## Step-by-Step Plugin Implementation

### Step 1: Create Version Module

```ruby
# lib/train-yourname/version.rb
module TrainPlugins
  module YourName
    VERSION = "0.1.0".freeze
  end
end
```

### Step 2: Implement Mock Mode First

**Why Mock Mode First?**
- Enables rapid development without target systems
- Allows test-driven development
- Essential for CI/CD pipelines

```ruby
# lib/train-yourname/connection.rb
def run_command_via_connection(cmd)
  return mock_command_result(cmd) if @options[:mock]
  
  # Real implementation here
end

private

def mock_command_result(cmd)
  case cmd
  when /version/
    CommandResult.new("Version 1.0.0", 0)
  when /status/
    CommandResult.new("Status: OK", 0)  
  else
    CommandResult.new("Unknown command: #{cmd}", 1)
  end
end

# Command result wrapper
class CommandResult
  attr_reader :stdout, :stderr, :exit_status
  
  def initialize(stdout, exit_status, stderr = "")
    @stdout = stdout.to_s
    @stderr = stderr.to_s
    @exit_status = exit_status.to_i
  end
end
```

### Step 3: Add Basic Transport Registration

```ruby
# lib/train-yourname/transport.rb
require "train-yourname/connection"

module TrainPlugins
  module YourName
    class Transport < Train.plugin(1)
      name "yourname"

      def connection(instance_opts = nil)
        opts = merge_options(options, instance_opts || {})
        Connection.new(opts)
      end
    end
  end
end
```

### Step 4: Implement Platform Detection

```ruby
# lib/train-yourname/platform.rb
module TrainPlugins::YourName
  module Platform
    PLATFORM_NAME = "yourname".freeze
    
    def platform
      Train::Platforms.name(PLATFORM_NAME)
        .title("Your System")
        .in_family("api")  # Choose: os, network, cloud, api
      
      force_platform!(PLATFORM_NAME, {
        release: TrainPlugins::YourName::VERSION,
        arch: "api"
      })
    end
  end
end
```

### Step 5: Create Entry Point

```ruby
# lib/train-yourname.rb
libdir = __dir__
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

require "train-yourname/version"
require "train-yourname/transport"
require "train-yourname/platform"
require "train-yourname/connection"
```

### Step 6: Test Your Basic Plugin

```bash
# Install dependencies
bundle install

# Test in Ruby
bundle exec ruby -e "
require './lib/train-yourname'
transport = Train.create('yourname', mock: true)
puts transport.connection.run_command('version').stdout
"
```

---

## Connection URI Design and Proxy Support

### Understanding Train URI Structure

When users run `inspec detect -t "juniper://user@host?option=value"`, Train parses this URI and converts it into options for your plugin. Understanding this process is critical for enterprise-ready plugins.

#### Standard URI Format

```
transport://[user[:password]@]host[:port][/path][?option1=value1&option2=value2]
```

**Examples:**
```bash
# Basic connection
juniper://admin@192.168.1.1

# With password in URI (not recommended)
juniper://admin:secret@192.168.1.1:2222

# With query parameters (recommended)
juniper://admin@192.168.1.1?port=2222&timeout=60
```

### Train URI Parsing Process

1. **InSpec Command**: `inspec detect -t "juniper://admin@switch?bastion_host=jump"`
2. **Train.target_config()**: Parses URI into options hash
3. **Train.create()**: Creates transport with parsed options
4. **Transport.connection()**: Passes options to your Connection class

#### Example Parsing Flow

```ruby
# Input URI
uri = "juniper://admin@device.corp?bastion_host=jump.corp&bastion_port=2222"

# Train.target_config() produces:
{
  backend: "juniper",
  host: "device.corp", 
  user: "admin",
  bastion_host: "jump.corp",
  bastion_port: "2222"  # Note: URI params are strings!
}

# Your Connection.initialize() receives these options
```

### Defining Connection Options in Transport

Your Transport class must define all supported options using the `option` DSL:

```ruby
class Transport < Train.plugin(1)
  name "yourname"
  
  # Required options
  option :host, required: true
  option :user, required: true
  
  # Optional connection options with defaults
  option :port, default: 22
  option :password, default: nil
  option :timeout, default: 30
  
  # Enterprise proxy options (Train standard)
  option :bastion_host, default: nil
  option :bastion_user, default: "root"
  option :bastion_port, default: 22
  option :proxy_command, default: nil
  
  # Advanced options
  option :key_files, default: nil
  option :keys_only, default: false
  option :keepalive, default: true
end
```

**Critical Rule**: Only options defined in your Transport will be available in your Connection!

### Implementing Enterprise Proxy Support

Enterprise environments typically require proxy/bastion connections. Here's how we implemented this in train-juniper:

#### Step 1: Add Proxy Options to Transport

```ruby
# In transport.rb - following Train SSH transport standards
option :bastion_host, default: nil
option :bastion_user, default: "root"
option :bastion_port, default: 22
option :proxy_command, default: nil
```

#### Step 2: Handle Proxy Options in Connection

```ruby
# In connection.rb initialize()
def initialize(options)
  @options = options.dup
  
  # Support environment variables for proxy options
  @options[:bastion_host] ||= ENV['JUNIPER_BASTION_HOST']
  @options[:bastion_user] ||= ENV['JUNIPER_BASTION_USER'] || 'root'
  @options[:bastion_port] ||= ENV['JUNIPER_BASTION_PORT']&.to_i || 22
  @options[:proxy_command] ||= ENV['JUNIPER_PROXY_COMMAND']
  
  # Validate proxy configuration early
  validate_proxy_options
  
  super(@options)
end

private

# Train standard: cannot use both bastion_host and proxy_command
def validate_proxy_options
  if @options[:bastion_host] && @options[:proxy_command]
    raise Train::ClientError, "Cannot specify both bastion_host and proxy_command"
  end
end
```

#### Step 3: Implement SSH Proxy Connection

```ruby
# In connection.rb connect() method
def connect
  ssh_options = {
    port: @options[:port] || 22,
    password: @options[:password],
    timeout: @options[:timeout] || 30,
    verify_host_key: :never
  }
  
  # Add proxy support following Train SSH transport standard
  proxy_config = setup_proxy_connection
  ssh_options[:proxy] = proxy_config if proxy_config
  
  @ssh_session = Net::SSH.start(@options[:host], @options[:user], ssh_options)
end

def setup_proxy_connection
  # Setup bastion host proxy (Train standard)
  if @options[:bastion_host]
    proxy_command = generate_bastion_proxy_command
    require 'net/ssh/proxy/command'
    return Net::SSH::Proxy::Command.new(proxy_command)
  end
  
  # Setup custom proxy command (Train standard)  
  if @options[:proxy_command]
    require 'net/ssh/proxy/command'
    return Net::SSH::Proxy::Command.new(@options[:proxy_command])
  end
  
  nil
end

def generate_bastion_proxy_command
  args = ['ssh']
  args += ['-o', 'UserKnownHostsFile=/dev/null']
  args += ['-o', 'StrictHostKeyChecking=no']
  args += ['-o', 'LogLevel=ERROR']
  args += ["#{@options[:bastion_user]}@#{@options[:bastion_host]}"]
  args += ['-p', @options[:bastion_port].to_s]
  args += ['-W', '%h:%p']  # SSH ProxyCommand format
  args.join(' ')
end
```

### Real-World URI Examples

With proper proxy support, these InSpec commands now work:

```bash
# Corporate network with jump host
inspec detect -t "juniper://admin@core-switch.internal?bastion_host=jump.corp.com&bastion_user=netadmin"

# Cloud environment with bastion instance  
inspec exec profile -t "juniper://ubuntu@10.0.1.100?bastion_host=bastion.aws.company.com&bastion_port=2222"

# Custom proxy command for complex routing
inspec shell -t "juniper://admin@device?proxy_command=ssh%20-o%20StrictHostKeyChecking=no%20jump%20nc%20%h%20%p"

# Multi-hop scenario
inspec detect -t "juniper://operator@firewall.dmz?bastion_host=jump.dmz.corp&bastion_user=svc_account"
```

### Environment Variable Strategy

Support environment variables for all connection options:

```bash
# Basic connection via env vars
export JUNIPER_HOST=internal.device.corp
export JUNIPER_USER=netadmin
export JUNIPER_PASSWORD=devicepass
export JUNIPER_BASTION_HOST=jump.corp.com
export JUNIPER_BASTION_USER=admin
inspec detect -t juniper://

# Explicit options override environment variables
inspec detect -t "juniper://different-user@different-host"
```

### Testing URI Parsing and Proxy Support

Add comprehensive tests for URI parsing and proxy functionality:

```ruby
# In test/integration/proxy_connection_test.rb
describe "URI parsing and proxy integration" do
  it "should parse bastion host from URI" do
    uri = "juniper://admin@device.local?bastion_host=jump.host&bastion_user=netadmin"
    config = Train.target_config(target: uri)
    
    _(config[:backend]).must_equal("juniper")
    _(config[:bastion_host]).must_equal("jump.host")
    _(config[:bastion_user]).must_equal("netadmin")
  end
  
  it "should create working connection with proxy" do
    transport = Train.create('juniper', {
      host: 'internal.device',
      user: 'admin',
      bastion_host: 'jump.company.com',
      mock: true
    })
    
    connection = transport.connection
    result = connection.run_command('show version')
    _(result.exit_status).must_equal(0)
  end
  
  it "should reject invalid proxy configurations" do
    _(-> {
      Train.create('juniper', {
        host: 'device.local',
        user: 'admin',
        bastion_host: 'jump.host',
        proxy_command: 'ssh proxy -W %h:%p',
        mock: true
      }).connection
    }).must_raise(Train::ClientError)
  end
end
```

### Key Insights from train-juniper Implementation

1. **URI Structure is Plugin-Defined**: Your `option` declarations in Transport determine what URI parameters are recognized

2. **Train Standard Patterns**: Follow Train SSH transport for proxy options (`bastion_host`, `proxy_command`) for consistency

3. **Environment Variables**: Essential for enterprise automation where credentials can't be in command lines

4. **Early Validation**: Validate proxy configurations in `initialize()` to fail fast with clear error messages

5. **Enterprise Ready**: Proxy/bastion support is not optional for production plugins - most enterprise devices are behind jump hosts

---

## Testing Your Plugin

### Test Structure

```
test/
├── helper.rb                  # Test setup
├── unit/
│   ├── transport_test.rb      # Plugin registration tests
│   └── connection_test.rb     # Connection logic tests
└── functional/
    └── yourname_test.rb       # End-to-end tests
```

### Test Helper (`test/helper.rb`)

```ruby
require "minitest/autorun"
require "minitest/spec"

# Load the plugin
require "train"
require "train-yourname"

# Test utilities
def mock_options
  { mock: true, host: "test", user: "test", password: "test" }
end
```

### Transport Tests (`test/unit/transport_test.rb`)

```ruby
require_relative "../helper"
require "train-yourname/transport"

describe TrainPlugins::YourName::Transport do
  let(:plugin_class) { TrainPlugins::YourName::Transport }

  it "should be registered with Train" do
    _(Train::Plugins.registry.keys).must_include("yourname")
    _(Train::Plugins.registry.keys).wont_include("train-yourname")
  end

  it "should inherit from Train plugin base" do
    _((plugin_class < Train.plugin(1))).must_equal(true)
  end

  it "should provide connection method" do
    _(plugin_class.instance_methods(false)).must_include(:connection)
  end
end
```

### Connection Tests (`test/unit/connection_test.rb`)

```ruby
require_relative "../helper"
require "train-yourname/connection"

describe TrainPlugins::YourName::Connection do
  let(:connection_class) { TrainPlugins::YourName::Connection }
  let(:connection) { connection_class.new(mock_options) }

  it "should inherit from BaseConnection" do
    _((connection_class < Train::Plugins::Transport::BaseConnection)).must_equal(true)
  end

  it "should execute commands in mock mode" do
    result = connection.run_command("version")
    _(result.exit_status).must_equal(0)
    _(result.stdout).must_match(/Version/)
  end

  it "should handle file operations" do
    file_obj = connection.file("/test/path")
    _(file_obj).wont_be_nil
  end
end
```

### Functional Tests (`test/functional/yourname_test.rb`)

```ruby
require_relative "../helper"

describe "train-yourname plugin" do
  it "should create transport without errors" do
    _(proc { Train.create("yourname", mock: true) }).must_be_silent
  end

  it "should establish connection" do
    transport = Train.create("yourname", mock: true)
    connection = transport.connection
    _(connection).wont_be_nil
  end

  it "should execute commands end-to-end" do
    connection = Train.create("yourname", mock: true).connection
    result = connection.run_command("version")
    _(result.exit_status).must_equal(0)
  end
end
```

### Running Tests

```bash
# Run all tests
bundle exec rake test

# Run specific test
bundle exec ruby test/unit/transport_test.rb

# Run with verbose output
bundle exec rake test TESTOPTS="--verbose"
```

---

## Platform Detection Strategies

### Understanding Platform Detection

Platform detection tells InSpec what type of system it's connected to. This affects:
- Which InSpec resources are available
- How file paths are interpreted  
- What default behaviors to use

### Strategy 1: Force Platform (Recommended)

**Use when**: You know exactly what platform your plugin targets

```ruby
def platform
  Train::Platforms.name(PLATFORM_NAME)
    .title("Your Platform")
    .in_family("network")
  
  force_platform!(PLATFORM_NAME, {
    release: detect_version || VERSION,
    arch: "network"
  })
end
```

**Benefits**:
- Fast - no detection commands needed
- Reliable - no detection can fail
- Standard pattern for dedicated plugins

### Strategy 2: Conditional Detection

**Use when**: Your plugin supports multiple platform variants

```ruby
def platform
  # Register all possible platforms
  Train::Platforms.name("yourbase").in_family("network")
  Train::Platforms.name("yourbase-v1").in_family("yourbase") 
  Train::Platforms.name("yourbase-v2").in_family("yourbase")
  
  # Detect which variant
  version = detect_version
  if version&.start_with?("2.")
    force_platform!("yourbase-v2", release: version)
  else
    force_platform!("yourbase-v1", release: version)
  end
end
```

### Platform Families

Choose the appropriate family for your platform:

- **`os`**: Operating systems (Linux, Windows, etc.)
- **`network`**: Network devices (routers, switches, firewalls)
- **`cloud`**: Cloud platforms (AWS, Azure, GCP)
- **`api`**: APIs and web services
- **`database`**: Database systems
- **`container`**: Container platforms

### Version Detection Best Practices

```ruby
def detect_version
  # Only detect if connection is ready
  return nil unless connected?
  return nil if @options[:mock]
  
  begin
    result = run_command_via_connection("version")
    return nil unless result&.exit_status == 0
    
    parse_version(result.stdout)
  rescue => e
    logger&.debug("Version detection failed: #{e.message}")
    nil
  end
end

def parse_version(output)
  # Use multiple patterns for robustness
  patterns = [
    /Version:\s+([\d\.]+)/,
    /v([\d\.]+)/,
    /([\d]+\.[\d]+(?:\.[\d]+)?)/
  ]
  
  patterns.each do |pattern|
    match = output.match(pattern)
    return match[1] if match
  end
  
  nil
end
```

---

## Connection Implementation Patterns

### Command Execution Patterns

#### Pattern 1: Simple API Calls

```ruby
def run_command_via_connection(cmd)
  response = @api_client.execute(cmd)
  
  CommandResult.new(
    response.body,
    response.success? ? 0 : 1,
    response.error_message
  )
end
```

#### Pattern 2: SSH-based Devices

```ruby
def run_command_via_connection(cmd)
  output = @ssh_session.exec!(cmd)
  
  # Parse device-specific error patterns
  if device_error?(output)
    CommandResult.new("", 1, output)
  else
    CommandResult.new(clean_output(output), 0)
  end
end

def device_error?(output)
  ERROR_PATTERNS.any? { |pattern| output.match?(pattern) }
end

ERROR_PATTERNS = [
  /^error:/i,
  /syntax error/i,
  /invalid command/i
].freeze
```

#### Pattern 3: Database Queries

```ruby
def run_command_via_connection(cmd)
  # Treat commands as SQL queries
  result = @db_connection.query(cmd)
  
  CommandResult.new(
    format_query_result(result),
    0  # Database queries typically don't have exit codes
  )
end
```

### File Operation Patterns

#### Pattern 1: Configuration Files (Network Devices)

```ruby
def file_via_connection(path)
  YourDeviceFile.new(self, path)
end

class YourDeviceFile
  def initialize(connection, path)
    @connection = connection
    @path = path
  end
  
  def content
    case @path
    when %r{^/config/(.+)}
      # Map file paths to device commands
      section = $1
      result = @connection.run_command("show config #{section}")
      result.stdout
    when %r{^/status/(.+)}
      section = $1
      result = @connection.run_command("show status #{section}")
      result.stdout
    else
      ""
    end
  end
  
  def exist?
    !content.empty?
  rescue
    false
  end
end
```

#### Pattern 2: API Resources

```ruby
def file_via_connection(path)
  APIResource.new(self, path)
end

class APIResource
  def content
    # Map file paths to API endpoints
    endpoint = @path.gsub("/", "")
    response = @connection.api_get(endpoint)
    response.to_json
  end
end
```

### Environment Variable Support

```ruby
def initialize(options)
  @options = options.dup
  
  # Support environment variables for all connection options
  @options[:host] ||= ENV['YOUR_HOST']
  @options[:user] ||= ENV['YOUR_USER']
  @options[:password] ||= ENV['YOUR_PASSWORD']
  @options[:token] ||= ENV['YOUR_TOKEN']
  @options[:port] ||= ENV['YOUR_PORT']&.to_i || default_port
  @options[:timeout] ||= ENV['YOUR_TIMEOUT']&.to_i || 30
  
  # SSL/TLS options
  @options[:ssl] = ENV['YOUR_SSL']&.downcase == 'true' if @options[:ssl].nil?
  @options[:verify_ssl] = ENV['YOUR_VERIFY_SSL']&.downcase != 'false'
  
  super(options)
end
```

### Connection State Management

```ruby
def initialize(options)
  super(options)
  @connection_state = :disconnected
  connect unless @options[:mock]
end

def connect
  return if connected?
  
  begin
    @client = establish_connection
    @connection_state = :connected
    configure_session if respond_to?(:configure_session)
  rescue => e
    @connection_state = :failed
    raise Train::TransportError, "Connection failed: #{e.message}"
  end
end

def connected?
  @connection_state == :connected && @client&.alive?
end

def close
  @client&.close
  @connection_state = :disconnected
end
```

---

## Advanced Patterns and Best Practices

### Error Handling Strategies

#### Graceful Degradation

```ruby
def run_command_via_connection(cmd)
  execute_with_retry(cmd, max_retries: 3)
rescue ConnectionError => e
  logger.warn("Connection lost, attempting reconnect: #{e.message}")
  reconnect
  execute_with_retry(cmd, max_retries: 1)
rescue => e
  logger.error("Command execution failed: #{e.message}")
  CommandResult.new("", 1, e.message)
end

def execute_with_retry(cmd, max_retries: 3)
  retries = 0
  begin
    actual_execute(cmd)
  rescue RetryableError => e
    retries += 1
    if retries <= max_retries
      sleep(2**retries)  # Exponential backoff
      retry
    else
      raise
    end
  end
end
```

#### Device-Specific Error Handling

```ruby
def handle_device_response(output)
  case output
  when /Authentication failed/i
    raise Train::UserError, "Invalid credentials"
  when /Permission denied/i
    raise Train::UserError, "Insufficient privileges"
  when /Connection timeout/i
    raise Train::TransientError, "Device not responding"
  when /Unknown command/i
    CommandResult.new("", 1, "Command not supported")
  else
    CommandResult.new(output, 0)
  end
end
```

### Performance Optimization

#### Connection Pooling

```ruby
class Connection < Train::Plugins::Transport::BaseConnection
  @@connection_pool = {}
  
  def initialize(options)
    super(options)
    @pool_key = "#{@options[:host]}:#{@options[:port]}:#{@options[:user]}"
  end
  
  def client
    @@connection_pool[@pool_key] ||= establish_connection
  end
  
  def self.close_all_connections
    @@connection_pool.values.each(&:close)
    @@connection_pool.clear
  end
end
```

#### Command Caching

```ruby
def run_command_via_connection(cmd)
  return cached_result(cmd) if cacheable?(cmd) && cached?(cmd)
  
  result = execute_command(cmd)
  cache_result(cmd, result) if cacheable?(cmd)
  result
end

def cacheable?(cmd)
  # Cache read-only commands
  cmd.match?(/^(show|get|list|describe)/)
end

def cache_result(cmd, result)
  @command_cache ||= {}
  @command_cache[cmd] = {
    result: result,
    timestamp: Time.now
  }
end

def cached_result(cmd)
  entry = @command_cache[cmd]
  return nil unless entry
  return nil if Time.now - entry[:timestamp] > cache_ttl
  
  entry[:result]
end
```

### Advanced Authentication

#### Multi-Factor Authentication

```ruby
def authenticate
  # Primary authentication
  authenticate_primary
  
  # Check if MFA is required
  if mfa_required?
    mfa_token = @options[:mfa_token] || prompt_for_mfa
    authenticate_mfa(mfa_token)
  end
end

def authenticate_primary
  case @options[:auth_method]
  when :password
    authenticate_password
  when :key
    authenticate_key
  when :token
    authenticate_token
  else
    raise Train::UserError, "Unsupported authentication method"
  end
end
```

#### Token Refresh

```ruby
def ensure_valid_token
  if token_expired?
    refresh_token
  end
end

def token_expired?
  return true unless @auth_token
  return true unless @token_expires_at
  
  Time.now >= @token_expires_at - 300  # Refresh 5 min early
end

def refresh_token
  response = @client.refresh_auth_token(@refresh_token)
  @auth_token = response.access_token
  @token_expires_at = Time.now + response.expires_in
end
```

### Configuration Management

#### Configuration Validation

```ruby
def validate_options
  required_options = [:host]
  required_options << :user unless @options[:token]
  required_options << :password unless @options[:key] || @options[:token]
  
  missing = required_options.select { |opt| @options[opt].nil? }
  unless missing.empty?
    raise Train::UserError, "Missing required options: #{missing.join(', ')}"
  end
  
  validate_port
  validate_ssl_options
end

def validate_port
  port = @options[:port]
  unless port.is_a?(Integer) && port.between?(1, 65535)
    raise Train::UserError, "Invalid port: #{port}"
  end
end
```

#### Default Configuration

```ruby
def apply_defaults
  @options[:port] ||= default_port
  @options[:timeout] ||= 30
  @options[:ssl] = true if @options[:ssl].nil?
  @options[:verify_ssl] = true if @options[:verify_ssl].nil?
  @options[:max_retries] ||= 3
  @options[:retry_delay] ||= 1
end

def default_port
  @options[:ssl] ? 443 : 80
end
```

---

## Packaging and Publishing

### Gemspec Best Practices

```ruby
# train-yourname.gemspec
lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "train-yourname/version"

Gem::Specification.new do |spec|
  # Required fields
  spec.name          = "train-yourname"
  spec.version       = TrainPlugins::YourName::VERSION
  spec.authors       = ["Your Name"]
  spec.email         = ["your@email.com"]
  spec.summary       = "Train transport for Your System"
  spec.description   = "Detailed description of what your plugin does and how it works."
  spec.homepage      = "https://github.com/yourorg/train-yourname"
  spec.license       = "Apache-2.0"
  
  # Metadata for better discovery
  spec.metadata = {
    "bug_tracker_uri"   => "https://github.com/yourorg/train-yourname/issues",
    "changelog_uri"     => "https://github.com/yourorg/train-yourname/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://github.com/yourorg/train-yourname/blob/main/README.md",
    "homepage_uri"      => "https://github.com/yourorg/train-yourname",
    "source_code_uri"   => "https://github.com/yourorg/train-yourname"
  }
  
  # File inclusion
  spec.files = %w{
    README.md train-yourname.gemspec LICENSE
  } + Dir.glob("lib/**/*", File::FNM_DOTMATCH).reject { |f| File.directory?(f) }
  
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 3.1.0"
  
  # Runtime dependencies
  spec.add_dependency "train-core", "~> 3.12"
  spec.add_dependency "your-sdk", "~> 1.0"
  
  # Do NOT add development dependencies here - use Gemfile
end
```

### README Template

```markdown
# Train YourName Plugin

Train plugin for connecting to Your System via SSH/API/etc.

## Installation

```bash
inspec plugin install train-yourname
```

## Usage

```bash
# Basic connection
inspec detect -t yourname://user@host --password secret

# With environment variables
export YOUR_HOST=host
export YOUR_USER=user
export YOUR_PASSWORD=secret
inspec shell -t yourname://
```

## Configuration Options

| Option | Description | Default | Environment Variable |
|--------|-------------|---------|---------------------|
| `host` | Target hostname | - | `YOUR_HOST` |
| `user` | Username | - | `YOUR_USER` |
| `password` | Password | - | `YOUR_PASSWORD` |

## Development

```bash
git clone https://github.com/yourorg/train-yourname
cd train-yourname
bundle install
bundle exec rake test
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request

## License

Apache 2.0
```

### Publishing Process

```bash
# 1. Build gem
gem build train-yourname.gemspec

# 2. Test installation locally
gem install train-yourname-*.gem

# 3. Test with InSpec
inspec plugin install train-yourname-*.gem
inspec detect -t yourname://test

# 4. Publish to RubyGems
gem push train-yourname-*.gem
```

### Version Management

```bash
# Update version
echo "0.2.0" > VERSION  # Or edit version.rb

# Tag release
git tag -a v0.2.0 -m "Release 0.2.0"
git push origin v0.2.0

# Build and publish
gem build train-yourname.gemspec
gem push train-yourname-0.2.0.gem
```

---

## Troubleshooting Common Issues

### Plugin Not Found

**Error**: `ArgumentError: Can't find train plugin yourname`

**Causes**:
1. Plugin not installed: `inspec plugin install train-yourname`
2. Wrong target URI: Use `yourname://` not `train-yourname://`
3. Plugin failed to load: Check for Ruby syntax errors

**Debug**:
```bash
# Check installed plugins
inspec plugin list

# Check plugin loading
ruby -e "require 'train-yourname'; puts 'OK'"
```

### Platform Detection Loops

**Error**: Infinite recursion in platform detection

**Cause**: Calling commands during platform detection before connection is ready

**Solution**: Use `force_platform!` instead of detection commands:

```ruby
# WRONG - Can cause loops
def platform
  result = run_command("version")  # Command before connection ready!
  # ...
end

# RIGHT - Force platform immediately  
def platform
  force_platform!("yourname", release: VERSION)
end
```

### Connection Timeouts

**Error**: Connection hangs or times out

**Causes**:
1. Network connectivity issues
2. Incorrect port/protocol
3. Authentication failures
4. Firewall blocking connection

**Debug**:
```ruby
def initialize(options)
  @options = options.dup
  @options[:timeout] ||= 10  # Shorter timeout for debugging
  @logger = Logger.new(STDOUT, level: Logger::DEBUG)  # Enable debug logs
  super(options)
end
```

### MiniTest Deprecation Warnings

**Error**: `DEPRECATED: global use of must_equal`

**Solution**: Use modern MiniTest syntax:

```ruby
# OLD - Deprecated
result.exit_status.must_equal(0)

# NEW - Correct
_(result.exit_status).must_equal(0)
```

### Train Version Conflicts

**Error**: Gem dependency conflicts with Train

**Solution**: Use `train-core` instead of `train`:

```ruby
# In gemspec
spec.add_dependency "train-core", "~> 3.12"

# In Gemfile  
gem "train-core", "~> 3.12"
```

### Mock Mode Not Working

**Error**: Tests try to make real connections

**Solution**: Ensure mock detection works:

```ruby
def run_command_via_connection(cmd)
  return mock_command_result(cmd) if mock_mode?
  # real implementation
end

def mock_mode?
  @options[:mock] == true
end
```

---

## Real-World Examples

### Network Device Plugin (train-juniper)

**Use Case**: Juniper routers and firewalls via SSH

**Key Features**:
- SSH with prompt handling
- JunOS command execution
- Configuration file access via pseudo-files
- Platform detection with version parsing

**Architecture**:
```ruby
# Connection uses direct SSH to avoid Train SSH detection loops
def connect
  require 'net/ssh'
  @ssh_session = Net::SSH.start(@options[:host], @options[:user], ssh_options)
  @ssh_connection = JuniperSSHConnection.new(@ssh_session, @logger)
end

# Commands mapped to JunOS CLI
def run_command_via_connection(cmd)
  output = @ssh_connection.exec(cmd)
  format_junos_result(output, cmd)
end

# Files mapped to configuration commands
def file_via_connection(path)
  case path
  when %r{^/config/(.+)}
    result = run_command("show configuration #{$1}")
    FileContent.new(result.stdout)
  end
end
```

### REST API Plugin (train-rest)

**Use Case**: REST APIs with various authentication methods

**Key Features**:
- Multiple auth methods (Bearer, API key, AWS SigV4)
- HTTP verb mapping to commands
- JSON response handling

**Architecture**:
```ruby
# Commands mapped to HTTP verbs
def run_command_via_connection(cmd)
  verb, path, body = parse_command(cmd)
  response = @rest_client.send(verb, path, body)
  
  CommandResult.new(
    response.body,
    response.code < 400 ? 0 : 1
  )
end

# Files mapped to GET requests
def file_via_connection(path)
  response = @rest_client.get(path)
  FileContent.new(response.body)
end
```

### Cloud API Plugin (train-aws)

**Use Case**: AWS services via SDK

**Key Features**:
- AWS credential chain
- Service-specific clients
- Resource enumeration

**Architecture**:
```ruby
# Multiple AWS service clients
def ec2_client
  @ec2_client ||= Aws::EC2::Client.new(@aws_opts)
end

def s3_client
  @s3_client ||= Aws::S3::Client.new(@aws_opts)
end

# Commands mapped to AWS API calls
def run_command_via_connection(cmd)
  service, action, params = parse_aws_command(cmd)
  client = send("#{service}_client")
  result = client.send(action, params)
  
  CommandResult.new(result.to_json, 0)
end
```

### Database Plugin Pattern

**Use Case**: SQL databases

**Key Features**:
- Connection pooling
- SQL query execution
- Result set formatting

**Architecture**:
```ruby
# Commands as SQL queries
def run_command_via_connection(cmd)
  result_set = @db_connection.query(cmd)
  
  CommandResult.new(
    format_result_set(result_set),
    0  # Databases don't have exit codes
  )
end

# Tables as files
def file_via_connection(path)
  table_name = path.gsub('/', '')
  query = "SELECT * FROM #{table_name} LIMIT 1000"
  result = run_command(query)
  FileContent.new(result.stdout)
end
```

---

## Summary: Key Success Factors

### Architecture Decisions

1. **Use `force_platform!`** - Don't try to implement Train's platform detection
2. **Implement mock mode first** - Essential for development and testing
3. **Use `train-core`** - Lighter weight than full `train` gem
4. **Follow 4-file structure** - version.rb, transport.rb, connection.rb, platform.rb

### Development Process

1. **Study community plugins** - Prospectra organization has best patterns
2. **Start with working examples** - Don't trust docs alone
3. **Test early and often** - Mock mode enables rapid iteration
4. **Use environment variables** - Standard pattern for configuration

### Common Pitfalls to Avoid

1. **Don't use Train's SSH transport** - Can cause detection loops
2. **Don't run commands during platform detection** - Use `force_platform!`
3. **Don't forget file operations** - Even if you return empty files
4. **Don't use deprecated MiniTest syntax** - Use `_(obj).must_equal`

### Community Resources

- **Official Example**: `train-local-rot13` in Train repository
- **Community Patterns**: Prospectra organization plugins
- **Production Examples**: `train-k8s-container`, `train-winrm`
- **Testing Tools**: containerlab, vrnetlab for network devices

---

**Future Development**: See [ROADMAP.md](../ROADMAP.md) for planned improvements and contribution opportunities.

---

*This guide was created during the development of train-juniper plugin for MITRE Corporation's Security Automation Framework (SAF) project. For questions or improvements, contact saf@mitre.org*
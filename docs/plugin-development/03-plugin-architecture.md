# Train Plugin Architecture

Understanding the mandatory 4-file structure and Train Plugin API v1 implementation patterns.

## Table of Contents

1. [The Four-File Structure](#the-four-file-structure)
2. [Plugin Entry Point](#plugin-entry-point)
3. [Transport Class (Plugin Registration)](#transport-class-plugin-registration)
4. [Connection Class (Core Implementation)](#connection-class-core-implementation)
5. [Platform Class (System Detection)](#platform-class-system-detection)
6. [Version Management](#version-management)
7. [Plugin Loading and Discovery](#plugin-loading-and-discovery)
8. [Implementation Examples](#implementation-examples)

---

## The Four-File Structure

Every Train plugin must follow this exact structure. This is not a suggestion - it's a requirement enforced by Train's plugin loading mechanism.

```
lib/
├── train-yourname.rb              # Entry point (REQUIRED)
└── train-yourname/
    ├── version.rb                 # Version constant (REQUIRED)
    ├── transport.rb               # Plugin registration (REQUIRED)
    ├── connection.rb              # Core implementation (REQUIRED)
    └── platform.rb                # Platform detection (REQUIRED)
```

### Why This Structure?

1. **Train Discovery**: Train scans for gems named `train-*` and loads `lib/train-name.rb`
2. **Consistent Loading**: All plugins follow the same loading pattern
3. **Separation of Concerns**: Each file has a specific responsibility
4. **Maintenance**: Clear structure makes plugins easier to understand and modify

### File Responsibilities

| File | Purpose | Key Contents |
|------|---------|-------------|
| `train-yourname.rb` | Plugin entry point | Requires all other files |
| `version.rb` | Version management | `VERSION` constant |
| `transport.rb` | Plugin registration | Transport class, options, factory method |
| `connection.rb` | Core functionality | Connection class, command execution, file operations |
| `platform.rb` | System identification | Platform detection logic |

---

## Plugin Entry Point

**File**: `lib/train-yourname.rb`

This file is Train's entry point for your plugin. It must require all other plugin files in the correct order.

```ruby
# lib/train-juniper.rb

# Set up load path for plugin files
libdir = File.dirname(__FILE__)
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

# Load plugin components in dependency order
require "train-juniper/version"    # Version constant (no dependencies)
require "train-juniper/platform"   # Platform detection (no dependencies)  
require "train-juniper/connection" # Connection class (uses platform)
require "train-juniper/transport"  # Transport class (uses connection)
```

### Loading Order Matters

```ruby
# CORRECT ORDER:
require "train-yourname/version"    # First - no dependencies
require "train-yourname/platform"   # Second - no dependencies
require "train-yourname/connection" # Third - may use platform
require "train-yourname/transport"  # Last - uses connection

# WRONG ORDER (will cause load errors):
require "train-yourname/transport"  # Fails - Connection not loaded yet
require "train-yourname/connection"
require "train-yourname/platform"
require "train-yourname/version"
```

### Load Path Management

```ruby
# Essential for Ruby to find your plugin files
libdir = File.dirname(__FILE__)
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

# Without this, Ruby can't resolve:
# require "train-yourname/version"  # Would fail!
```

---

## Transport Class (Plugin Registration)

**File**: `lib/train-yourname/transport.rb`

The Transport class registers your plugin with Train and defines all connection options.

```ruby
# lib/train-juniper/transport.rb
require "train-juniper/connection"

module TrainPlugins
  module Juniper
    class Transport < Train.plugin(1)  # ONLY v1 exists!
      name "juniper"  # This is how users reference your plugin

      # Define all connection options with defaults
      option :host, required: true
      option :port, default: 22
      option :user, required: true
      option :password, default: nil
      option :timeout, default: 30
      
      # Enterprise proxy options (Train standard)
      option :bastion_host, default: nil
      option :bastion_user, default: "root"
      option :bastion_port, default: 22
      option :proxy_command, default: nil

      # Factory method - Train calls this to get connections
      def connection(_instance_opts = nil)
        # Cache the connection for reuse
        @connection ||= TrainPlugins::Juniper::Connection.new(@options)
      end
    end
  end
end
```

### Critical Rules

1. **Plugin API Version**: Only `Train.plugin(1)` exists - don't use `Train.plugin(2)`!
2. **Name Registration**: `name "juniper"` registers as `juniper://`, not `train-juniper://`
3. **Option Definitions**: All URI parameters must be defined as options
4. **Namespace**: Must use `TrainPlugins::YourName` module structure
5. **Connection Factory**: `connection()` method must return your Connection instance

### Option Definition Patterns

```ruby
# Required options
option :host, required: true
option :user, required: true

# Optional with defaults
option :port, default: 22
option :timeout, default: 30

# Optional without defaults
option :password, default: nil
option :key_files, default: nil

# Boolean options
option :ssl, default: true
option :verify_ssl, default: true

# Enterprise patterns
option :bastion_host, default: nil
option :proxy_command, default: nil

# Environment variable support (handled in Connection)
# Don't put ENV[] calls in Transport - do it in Connection initialize()
```

### Option Types and URI Parsing

Remember: All URI parameters come as strings!

```ruby
# URI: juniper://admin@host:22?timeout=30&ssl=true
# Train passes to Transport as:
{
  "backend" => "juniper",
  "host" => "host",
  "user" => "admin", 
  "port" => "22",      # String!
  "timeout" => "30",   # String!
  "ssl" => "true"      # String!
}
```

---

## Connection Class (Core Implementation)

**File**: `lib/train-yourname/connection.rb`

This is where the real work happens - connecting to target systems and executing commands.

```ruby
# lib/train-juniper/connection.rb
require "train"
require "logger"
require "train-juniper/platform"

module TrainPlugins
  module Juniper
    class Connection < Train::Plugins::Transport::BaseConnection
      include TrainPlugins::Juniper::Platform  # Platform detection

      def initialize(options)
        @options = options.dup
        
        # Environment variable support
        @options[:host] ||= ENV['JUNIPER_HOST']
        @options[:user] ||= ENV['JUNIPER_USER']
        @options[:password] ||= ENV['JUNIPER_PASSWORD']
        
        # Convert string URI parameters to correct types
        @options[:port] = @options[:port].to_i if @options[:port]
        @options[:timeout] = @options[:timeout].to_i if @options[:timeout]
        
        # Set up logging
        @logger = @options[:logger] || Logger.new(STDOUT, level: Logger::WARN)
        
        super(@options)
        
        # Establish connection (unless in mock mode)
        connect unless @options[:mock]
      end

      # REQUIRED: Command execution
      def run_command_via_connection(cmd)
        return mock_command_result(cmd) if @options[:mock]
        
        begin
          @logger.debug("Executing: #{cmd}")
          output = @ssh_session.exec!(cmd)
          CommandResult.new(output || "", 0)
        rescue => e
          @logger.error("Command failed: #{e.message}")
          CommandResult.new("", 1, e.message)
        end
      end

      # REQUIRED: File operations  
      def file_via_connection(path)
        YourFileHandler.new(self, path)
      end

      private

      def connect
        # Your connection logic here
        require 'net/ssh'
        @ssh_session = Net::SSH.start(@options[:host], @options[:user], {
          port: @options[:port],
          password: @options[:password],
          timeout: @options[:timeout]
        })
      end

      def connected?
        !@ssh_session.nil? && @ssh_session.transport.open?
      end
    end
  end
end
```

### Required Methods

Every Connection class must implement:

1. **`run_command_via_connection(cmd)`** - Execute commands on target system
2. **`file_via_connection(path)`** - Handle file operations

### Command Result Format

```ruby
class CommandResult
  attr_reader :stdout, :stderr, :exit_status
  
  def initialize(stdout, exit_status, stderr = "")
    @stdout = stdout.to_s
    @stderr = stderr.to_s  
    @exit_status = exit_status.to_i
  end
end

# Usage in run_command_via_connection:
def run_command_via_connection(cmd)
  output = execute_somehow(cmd)
  CommandResult.new(output, 0)  # success
  # or
  CommandResult.new("", 1, "Error message")  # failure
end
```

### File Handler Pattern

```ruby
class YourFileHandler
  def initialize(connection, path)
    @connection = connection
    @path = path
  end
  
  def content
    # Map file paths to appropriate commands
    case @path
    when %r{^/config/(.+)}
      result = @connection.run_command("show config #{$1}")
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

---

## Platform Class (System Detection)

**File**: `lib/train-yourname/platform.rb`

Platform detection tells InSpec what type of system it's connected to.

```ruby
# lib/train-juniper/platform.rb
module TrainPlugins::Juniper
  module Platform
    PLATFORM_NAME = "juniper".freeze
    
    def platform
      # Register platform in Train's registry
      Train::Platforms.name(PLATFORM_NAME)
        .title("Juniper JunOS")
        .in_family("network")
      
      # Force platform (recommended for dedicated plugins)
      force_platform!(PLATFORM_NAME, {
        release: detect_version || TrainPlugins::Juniper::VERSION,
        arch: "network"
      })
    end

    private

    def detect_version
      return nil if @options&.dig(:mock)
      return nil unless connected?
      
      begin
        result = run_command_via_connection("show version")
        return nil unless result.exit_status == 0
        
        # Parse version from output
        if match = result.stdout.match(/Junos:\s+([\d\w\.-]+)/)
          match[1]
        end
      rescue
        nil
      end
    end
  end
end
```

### Platform Detection Strategies

#### Strategy 1: Force Platform (Recommended)

**Use when**: You know exactly what platform your plugin targets

```ruby
def platform
  Train::Platforms.name("yourname").in_family("network")
  force_platform!("yourname", {
    release: detect_version || VERSION,
    arch: "network" 
  })
end
```

**Benefits:**
- Bypasses Train's automatic detection
- Prevents detection commands running before connection ready
- Standard pattern for dedicated transport plugins

#### Strategy 2: Detection Commands

**Use when**: Your plugin supports multiple related platforms

```ruby
def platform
  detect_via_command("show version") do |output|
    case output
    when /JunOS/
      { name: "juniper", family: "network" }
    when /IOS/  
      { name: "cisco-ios", family: "network" }
    end
  end
end
```

### Platform Families

Common platform families:
- `"network"` - Network devices (routers, switches, firewalls)
- `"cloud"` - Cloud APIs and resources
- `"container"` - Containerized systems
- `"windows"` - Windows systems
- `"unix"` - Unix/Linux systems

---

## Version Management

**File**: `lib/train-yourname/version.rb`

Simple version constant following semantic versioning.

```ruby
# lib/train-juniper/version.rb
module TrainPlugins
  module Juniper
    VERSION = "0.1.0".freeze
  end
end
```

### Version Usage

```ruby
# In platform.rb
force_platform!("juniper", {
  release: detect_version || TrainPlugins::Juniper::VERSION
})

# In gemspec
spec.version = TrainPlugins::Juniper::VERSION

# In Transport (if needed)
option :plugin_version, default: TrainPlugins::Juniper::VERSION
```

---

## Plugin Loading and Discovery

### How Train Finds Your Plugin

1. **Gem Installation**: User runs `inspec plugin install train-yourname`
2. **Gem Discovery**: Train scans installed gems for `train-*` pattern
3. **File Loading**: Train requires `lib/train-yourname.rb`
4. **Class Registration**: Your Transport class registers with Train
5. **URI Resolution**: User runs `inspec -t yourname://...`
6. **Plugin Activation**: Train creates your Transport and Connection

### Registration Process

```ruby
# Your Transport class:
class Transport < Train.plugin(1)
  name "yourname"  # Registers as "yourname"
end

# Train's internal registry:
Train::Plugins.registry["yourname"] = YourTransport

# User URI resolution:
"yourname://host" → Train::Plugins.registry["yourname"]
```

### Common Registration Issues

```ruby
# WRONG: Don't include "train-" prefix
class Transport < Train.plugin(1)
  name "train-yourname"  # Users would need train-yourname://
end

# WRONG: Case sensitivity matters  
class Transport < Train.plugin(1)
  name "YourName"  # Users need YourName://, not yourname://
end

# CORRECT:
class Transport < Train.plugin(1)
  name "yourname"  # Users can use yourname://
end
```

---

## Implementation Examples

### Minimal Working Plugin

```ruby
# lib/train-hello/version.rb
module TrainPlugins::Hello
  VERSION = "0.1.0".freeze
end

# lib/train-hello/platform.rb  
module TrainPlugins::Hello::Platform
  def platform
    force_platform!("hello", release: TrainPlugins::Hello::VERSION)
  end
end

# lib/train-hello/connection.rb
class TrainPlugins::Hello::Connection < Train::Plugins::Transport::BaseConnection
  include TrainPlugins::Hello::Platform
  
  def run_command_via_connection(cmd)
    CommandResult.new("Hello: #{cmd}", 0)
  end
  
  def file_via_connection(path)
    HelloFile.new(path)
  end
end

# lib/train-hello/transport.rb
class TrainPlugins::Hello::Transport < Train.plugin(1)
  name "hello"
  option :host, required: true
  
  def connection(_instance_opts = nil)
    @connection ||= TrainPlugins::Hello::Connection.new(@options)
  end
end

# lib/train-hello.rb
require "train-hello/version"
require "train-hello/platform"
require "train-hello/connection"
require "train-hello/transport"
```

### Testing the Structure

```bash
# Test plugin loading
bundle exec ruby -e "
require './lib/train-hello'
transport = Train.create('hello', host: 'test')
puts transport.connection.run_command('version').stdout
"
# Output: "Hello: version"
```

---

## Key Takeaways

1. **Four-file structure is mandatory** - Train won't load plugins that don't follow this pattern
2. **Only Train.plugin(1) exists** - Don't try to use version 2
3. **Name registration matters** - `name "yourname"` becomes `yourname://` in URIs
4. **Options define URI parameters** - All URI query parameters must be declared as options
5. **Platform detection strategy** - Use `force_platform!` for dedicated transport plugins
6. **Loading order is critical** - Require files in dependency order

**Next**: Learn how to design connection URIs with [URI Design Patterns](04-uri-design-patterns.md).
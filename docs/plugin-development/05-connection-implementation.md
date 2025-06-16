# Connection Implementation

Building the core functionality of your Train plugin - command execution, file operations, and connection management.

## Table of Contents

1. [Connection Class Overview](#connection-class-overview)
2. [Required Methods](#required-methods)
3. [Connection Lifecycle](#connection-lifecycle)
4. [Command Execution Patterns](#command-execution-patterns)
5. [File Operation Patterns](#file-operation-patterns)
6. [Error Handling Strategies](#error-handling-strategies)
7. [Mock Mode Implementation](#mock-mode-implementation)
8. [Real-World Examples](#real-world-examples)

---

## Connection Class Overview

The Connection class is the heart of your Train plugin. It handles:

- Establishing connections to target systems
- Executing commands and returning results
- Providing file system abstraction
- Managing connection state and lifecycle
- Implementing platform detection

### Basic Structure

```ruby
# lib/train-yourname/connection.rb
require "train"
require "logger"
require "train-yourname/platform"

module TrainPlugins
  module YourName
    class Connection < Train::Plugins::Transport::BaseConnection
      include TrainPlugins::YourName::Platform
      
      def initialize(options)
        @options = options.dup
        setup_connection_options
        super(@options)
        connect unless @options[:mock]
      end

      # REQUIRED: Execute commands
      def run_command_via_connection(cmd)
        # Your implementation here
      end

      # REQUIRED: File operations
      def file_via_connection(path)
        # Your implementation here
      end

      private

      def connect
        # Establish connection to target system
      end

      def connected?
        # Check if connection is active
      end
    end
  end
end
```

---

## Required Methods

Every Connection class must implement these two methods:

### 1. Command Execution

```ruby
def run_command_via_connection(cmd)
  # Must return object with .stdout, .stderr, .exit_status
end
```

### 2. File Operations

```ruby
def file_via_connection(path)
  # Must return object with .content, .exist? methods
end
```

### Command Result Format

Train expects command results with specific attributes:

```ruby
class CommandResult
  attr_reader :stdout, :stderr, :exit_status
  
  def initialize(stdout, exit_status, stderr = "")
    @stdout = stdout.to_s
    @stderr = stderr.to_s
    @exit_status = exit_status.to_i
  end
end

# Usage examples:
CommandResult.new("output", 0)                    # Success
CommandResult.new("", 1, "error message")         # Failure
CommandResult.new("partial output", 130, "warn")  # Interrupted
```

---

## Connection Lifecycle

### Initialization Pattern

```ruby
def initialize(options)
  @options = options.dup
  
  # Handle environment variables
  setup_environment_variables
  
  # Convert URI string parameters to correct types
  convert_option_types
  
  # Validate configuration
  validate_options
  
  # Set up logging
  setup_logging
  
  # Call parent class
  super(@options)
  
  # Establish connection (unless in mock mode)
  connect unless @options[:mock]
end

private

def setup_environment_variables
  @options[:host] ||= ENV['YOUR_HOST']
  @options[:user] ||= ENV['YOUR_USER']
  @options[:password] ||= ENV['YOUR_PASSWORD']
  @options[:port] ||= ENV['YOUR_PORT']&.to_i || default_port
end

def convert_option_types
  # URI parameters come as strings - convert as needed
  @options[:port] = @options[:port].to_i if @options[:port]
  @options[:timeout] = @options[:timeout].to_i if @options[:timeout]
  @options[:ssl] = @options[:ssl] == 'true' if @options.key?(:ssl)
end

def validate_options
  raise Train::ClientError, "host is required" unless @options[:host]
  raise Train::ClientError, "user is required" unless @options[:user]
end

def setup_logging
  @logger = @options[:logger] || Logger.new(STDOUT, level: Logger::WARN)
  @logger.level = Logger::DEBUG if ENV["DEBUG"]
end
```

### Connection Management

```ruby
def connect
  return if connected?
  
  begin
    @logger.debug("Connecting to #{@options[:host]}:#{@options[:port]}")
    
    # Your connection logic here
    establish_connection
    
    # Post-connection setup
    configure_session if respond_to?(:configure_session)
    
    @logger.debug("Connection established successfully")
  rescue => e
    @logger.error("Connection failed: #{e.message}")
    raise Train::TransportError, "Failed to connect: #{e.message}"
  end
end

def connected?
  # Check if your connection is still active
  !@client.nil? && @client.alive?
end

def close
  @client&.close
  @client = nil
end
```

---

## Command Execution Patterns

### Pattern 1: SSH-Based Execution

```ruby
def run_command_via_connection(cmd)
  return mock_command_result(cmd) if @options[:mock]
  
  begin
    @logger.debug("Executing: #{cmd}")
    
    # Execute via SSH
    output = @ssh_session.exec!(cmd)
    
    @logger.debug("Command output: #{output}")
    
    # Process output for target system
    process_command_result(output, cmd)
  rescue => e
    @logger.error("Command execution failed: #{e.message}")
    CommandResult.new("", 1, e.message)
  end
end

private

def process_command_result(output, cmd)
  # Handle target system-specific error patterns
  if system_error?(output)
    CommandResult.new("", 1, output)
  else
    cleaned_output = clean_output(output, cmd)
    CommandResult.new(cleaned_output, 0)
  end
end

def system_error?(output)
  error_patterns = [
    /^error:/i,
    /syntax error/i,
    /invalid command/i,
    /unknown command/i
  ]
  
  error_patterns.any? { |pattern| output.match?(pattern) }
end

def clean_output(output, cmd)
  # Remove command echo and prompts
  lines = output.split("\n")
  lines.reject! { |line| line.strip == cmd.strip }
  lines.join("\n")
end
```

### Pattern 2: API-Based Execution

```ruby
def run_command_via_connection(cmd)
  return mock_command_result(cmd) if @options[:mock]
  
  begin
    # Map commands to API endpoints
    endpoint = map_command_to_endpoint(cmd)
    
    @logger.debug("API call: #{endpoint}")
    
    # Execute HTTP request
    response = @http_client.get(endpoint)
    
    # Process API response
    process_api_response(response)
  rescue => e
    @logger.error("API call failed: #{e.message}")
    CommandResult.new("", 1, e.message)
  end
end

private

def map_command_to_endpoint(cmd)
  case cmd
  when /^show version$/
    "/api/v1/system/version"
  when /^show config$/
    "/api/v1/config"
  when /^show status$/
    "/api/v1/status"
  else
    raise "Unknown command: #{cmd}"
  end
end

def process_api_response(response)
  if response.status == 200
    # Format JSON response as text output
    JSON.pretty_generate(response.body)
    CommandResult.new(formatted_output, 0)
  else
    CommandResult.new("", response.status, response.body)
  end
end
```

### Pattern 3: Cloud SDK Execution

```ruby
def run_command_via_connection(cmd)
  return mock_command_result(cmd) if @options[:mock]
  
  begin
    # Parse command into SDK method call
    method, args = parse_command(cmd)
    
    @logger.debug("SDK call: #{method}(#{args})")
    
    # Execute via cloud SDK
    result = @sdk_client.send(method, *args)
    
    # Format SDK response as command output
    format_sdk_result(result)
  rescue => e
    @logger.error("SDK call failed: #{e.message}")
    CommandResult.new("", 1, e.message)
  end
end

private

def parse_command(cmd)
  case cmd
  when /^describe-instances?$/
    [:describe_instances, []]
  when /^describe-instance (.+)$/
    [:describe_instances, [instance_ids: [$1]]]
  else
    raise "Unknown command: #{cmd}"
  end
end

def format_sdk_result(result)
  output = result.to_h.to_json
  CommandResult.new(output, 0)
end
```

---

## File Operation Patterns

### Pattern 1: Configuration File Mapping

```ruby
def file_via_connection(path)
  YourFileHandler.new(self, path)
end

class YourFileHandler
  def initialize(connection, path)
    @connection = connection
    @path = path
  end
  
  def content
    case @path
    when %r{^/config/(.+)}
      # Map config paths to show commands
      section = $1
      result = @connection.run_command("show config #{section}")
      result.stdout
    when %r{^/status/(.+)}
      # Map status paths to show commands
      section = $1
      result = @connection.run_command("show status #{section}")
      result.stdout
    when %r{^/logs/(.+)}
      # Map log paths to log commands
      log_type = $1
      result = @connection.run_command("show log #{log_type}")
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
  
  # Additional file methods as needed
  def size
    content.bytesize
  end
  
  def readable?
    exist?
  end
end
```

### Pattern 2: API Resource Mapping

```ruby
class APIFileHandler
  def initialize(connection, path)
    @connection = connection
    @path = path
  end
  
  def content
    # Map file paths to API endpoints
    endpoint = map_path_to_endpoint(@path)
    
    begin
      response = @connection.api_get(endpoint)
      format_response(response)
    rescue => e
      @connection.logger.debug("File not found: #{@path} -> #{e.message}")
      ""
    end
  end
  
  private
  
  def map_path_to_endpoint(path)
    case path
    when %r{^/api/(.+)}
      # Direct API path mapping
      $1
    when %r{^/config/(.+)}
      # Config paths to configuration API
      "configuration/#{$1}"
    when %r{^/metrics/(.+)}
      # Metrics paths to metrics API
      "metrics/#{$1}"
    else
      raise "Unknown path: #{path}"
    end
  end
  
  def format_response(response)
    case response.content_type
    when /json/
      JSON.pretty_generate(response.body)
    when /xml/
      response.body  # Return XML as-is
    else
      response.body.to_s
    end
  end
end
```

### Pattern 3: Cloud Resource Files

```ruby
class CloudFileHandler
  def initialize(connection, path)
    @connection = connection
    @path = path
  end
  
  def content
    # Map paths to cloud resource queries
    case @path
    when %r{^/instances/(.+)/metadata$}
      instance_id = $1
      get_instance_metadata(instance_id)
    when %r{^/instances/(.+)/userdata$}
      instance_id = $1
      get_instance_userdata(instance_id)
    when %r{^/security-groups/(.+)$}
      sg_id = $1
      get_security_group_rules(sg_id)
    else
      ""
    end
  end
  
  private
  
  def get_instance_metadata(instance_id)
    result = @connection.run_command("describe-instance #{instance_id}")
    # Parse JSON response and format as readable text
    data = JSON.parse(result.stdout)
    format_instance_metadata(data)
  end
end
```

---

## Error Handling Strategies

### Graceful Degradation

```ruby
def run_command_via_connection(cmd)
  return mock_command_result(cmd) if @options[:mock]
  
  begin
    execute_command(cmd)
  rescue ConnectionError => e
    # Try to reconnect once
    @logger.warn("Connection lost, attempting reconnect: #{e.message}")
    reconnect
    execute_command(cmd)
  rescue TimeoutError => e
    @logger.error("Command timeout: #{e.message}")
    CommandResult.new("", 124, "Command timed out")
  rescue SystemError => e
    @logger.error("System error: #{e.message}")
    CommandResult.new("", 1, e.message)
  rescue => e
    @logger.error("Unexpected error: #{e.message}")
    CommandResult.new("", 255, "Internal error")
  end
end
```

### Retry Logic

```ruby
def execute_with_retry(cmd, max_retries: 3)
  retries = 0
  
  begin
    execute_command(cmd)
  rescue TransientError => e
    retries += 1
    if retries <= max_retries
      @logger.warn("Retry #{retries}/#{max_retries}: #{e.message}")
      sleep(retries * 2)  # Exponential backoff
      retry
    else
      @logger.error("Max retries exceeded: #{e.message}")
      raise
    end
  end
end
```

### Connection Health Monitoring

```ruby
def run_command_via_connection(cmd)
  ensure_connected
  execute_command(cmd)
end

private

def ensure_connected
  return if connected?
  
  @logger.warn("Connection not active, reconnecting...")
  connect
end

def connected?
  return false unless @client
  
  # Perform lightweight check
  begin
    @client.ping || @client.alive?
  rescue
    false
  end
end
```

---

## Mock Mode Implementation

Mock mode is essential for rapid development and testing without real target systems.

### Basic Mock Implementation

```ruby
def run_command_via_connection(cmd)
  return mock_command_result(cmd) if @options[:mock]
  
  # Real implementation...
end

private

def mock_command_result(cmd)
  case cmd
  when /show version/
    CommandResult.new(mock_version_output, 0)
  when /show config/
    CommandResult.new(mock_config_output, 0)
  when /show status/
    CommandResult.new(mock_status_output, 0)
  when /invalid/
    CommandResult.new("", 1, "Invalid command")
  else
    CommandResult.new("Mock: #{cmd}", 0)
  end
end

def mock_version_output
  <<~OUTPUT
    System Version: 1.0.0
    Build: 20231201
    Uptime: 5 days, 3 hours
  OUTPUT
end

def mock_config_output
  <<~OUTPUT
    interface eth0
      ip address 192.168.1.100/24
      status up
    interface eth1
      ip address 10.0.1.100/24
      status down
  OUTPUT
end
```

### Advanced Mock with State

```ruby
class MockState
  def initialize
    @interfaces = {
      "eth0" => { ip: "192.168.1.100/24", status: "up" },
      "eth1" => { ip: "10.0.1.100/24", status: "down" }
    }
    @uptime = Time.now - (5 * 24 * 60 * 60)  # 5 days ago
  end
  
  def interface_status(name)
    @interfaces[name] || { status: "not found" }
  end
  
  def system_uptime
    seconds = Time.now - @uptime
    "#{(seconds / 86400).to_i} days, #{((seconds % 86400) / 3600).to_i} hours"
  end
end

def mock_command_result(cmd)
  @mock_state ||= MockState.new
  
  case cmd
  when /show interface (\w+)/
    interface = $1
    status = @mock_state.interface_status(interface)
    CommandResult.new("Interface #{interface}: #{status[:status]}", 0)
  when /show uptime/
    CommandResult.new(@mock_state.system_uptime, 0)
  else
    CommandResult.new("Mock: #{cmd}", 0)
  end
end
```

---

## Real-World Examples

### SSH Network Device (train-juniper)

```ruby
def run_command_via_connection(cmd)
  return mock_command_result(cmd) if @options[:mock]
  
  begin
    ensure_connected
    
    @logger.debug("Executing: #{cmd}")
    
    # Execute command via SSH
    output = @ssh_session.exec!(cmd)
    
    # Clean and validate output
    if junos_error?(output)
      CommandResult.new("", 1, output)
    else
      cleaned = clean_junos_output(output, cmd)
      CommandResult.new(cleaned, 0)
    end
    
  rescue => e
    @logger.error("Command failed: #{e.message}")
    CommandResult.new("", 1, e.message)
  end
end

private

def junos_error?(output)
  JUNOS_ERROR_PATTERNS.any? { |pattern| output.match?(pattern) }
end

JUNOS_ERROR_PATTERNS = [
  /^error:/i,
  /syntax error/i,
  /invalid command/i,
  /unknown command/i,
  /missing argument/i
].freeze

def clean_junos_output(output, cmd)
  lines = output.split("\n")
  # Remove command echo
  lines.reject! { |line| line.strip == cmd.strip }
  # Remove CLI prompts
  lines.reject! { |line| line.match?(/[%>$#]\s*$/) }
  lines.join("\n")
end
```

### REST API (train-rest)

```ruby
def run_command_via_connection(cmd)
  return mock_command_result(cmd) if @options[:mock]
  
  begin
    # Parse command into HTTP method and path
    method, path, body = parse_rest_command(cmd)
    
    @logger.debug("#{method.upcase} #{@base_url}#{path}")
    
    # Execute HTTP request
    response = @http_client.send(method, path, body)
    
    # Format response
    format_rest_response(response)
    
  rescue => e
    @logger.error("REST call failed: #{e.message}")
    CommandResult.new("", 1, e.message)
  end
end

private

def parse_rest_command(cmd)
  case cmd
  when /^GET (.+)$/
    [:get, $1, nil]
  when /^POST (.+) (.+)$/
    [:post, $1, $2]
  when /^PUT (.+) (.+)$/
    [:put, $1, $2]
  when /^DELETE (.+)$/
    [:delete, $1, nil]
  else
    raise "Invalid REST command: #{cmd}"
  end
end

def format_rest_response(response)
  status_line = "Status: #{response.status}"
  headers = response.headers.map { |k, v| "#{k}: #{v}" }.join("\n")
  body = format_response_body(response.body, response.content_type)
  
  output = [status_line, headers, "", body].join("\n")
  exit_status = response.status < 400 ? 0 : 1
  
  CommandResult.new(output, exit_status)
end
```

---

## Key Takeaways

1. **Implement required methods** - `run_command_via_connection` and `file_via_connection` are mandatory
2. **Handle connection lifecycle** - Connect, monitor health, reconnect as needed
3. **Support mock mode** - Essential for development and testing
4. **Graceful error handling** - Provide meaningful error messages and recovery
5. **Target system expertise** - Deep understanding of your target system's quirks and patterns

**Next**: Learn about [Proxy and Authentication](06-proxy-authentication.md) for enterprise-ready plugins.
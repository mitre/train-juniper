# Best Practices

Production-ready patterns for error handling, performance optimization, security, and maintainable Train plugin development.

## Table of Contents

1. [Error Handling Strategies](#error-handling-strategies)
2. [Performance Optimization](#performance-optimization)
3. [Security Best Practices](#security-best-practices)
4. [Code Organization](#code-organization)
5. [Logging and Debugging](#logging-and-debugging)
6. [Cross-Platform Considerations](#cross-platform-considerations)
7. [Maintenance and Evolution](#maintenance-and-evolution)
8. [Production Deployment](#production-deployment)

---

## Error Handling Strategies

### Graceful Degradation

Design your plugin to handle failures gracefully rather than crashing InSpec workflows.

```ruby
def run_command_via_connection(cmd)
  return mock_command_result(cmd) if @options[:mock]
  
  begin
    execute_command_with_retry(cmd)
  rescue ConnectionError => e
    # Attempt reconnection once
    @logger.warn("Connection lost, attempting reconnect: #{e.message}")
    reconnect
    execute_command(cmd)
  rescue TimeoutError => e
    @logger.error("Command timeout after #{@options[:timeout]}s: #{e.message}")
    CommandResult.new("", 124, "Command timed out: #{cmd}")
  rescue AuthenticationError => e
    @logger.error("Authentication failed: #{e.message}")
    CommandResult.new("", 1, "Authentication failed")
  rescue SystemError => e
    @logger.error("System error: #{e.message}")
    CommandResult.new("", 1, clean_error_message(e.message))
  rescue => e
    @logger.error("Unexpected error: #{e.class} - #{e.message}")
    CommandResult.new("", 255, "Internal plugin error")
  end
end

private

def clean_error_message(message)
  # Remove sensitive information from error messages
  message.gsub(/password[:\s=]+\S+/i, 'password=***')
         .gsub(/token[:\s=]+\S+/i, 'token=***')
         .gsub(/key[:\s=]+\S+/i, 'key=***')
end
```

### Retry Logic with Exponential Backoff

```ruby
def execute_command_with_retry(cmd, max_retries: 3)
  retries = 0
  
  begin
    execute_command(cmd)
  rescue TransientError => e
    retries += 1
    if retries <= max_retries
      delay = [2 ** retries, 30].min  # Cap at 30 seconds
      @logger.warn("Retry #{retries}/#{max_retries} after #{delay}s: #{e.message}")
      sleep(delay)
      retry
    else
      @logger.error("Max retries exceeded: #{e.message}")
      raise
    end
  end
end

# Define which errors are worth retrying
class TransientError < StandardError; end
class ConnectionResetError < TransientError; end
class TemporaryUnavailableError < TransientError; end
class RateLimitError < TransientError; end
```

### User-Friendly Error Messages

```ruby
def validate_connection_options
  errors = []
  
  errors << "Host is required" unless @options[:host]
  errors << "User is required" unless @options[:user]
  errors << "Port must be between 1 and 65535" unless valid_port?(@options[:port])
  
  if @options[:bastion_host] && @options[:proxy_command]
    errors << "Cannot specify both bastion_host and proxy_command"
  end
  
  unless errors.empty?
    raise Train::ClientError, "Configuration errors:\n  - #{errors.join("\n  - ")}"
  end
end

def connection_failed_message(error)
  case error
  when Net::SSH::AuthenticationFailed
    "Authentication failed. Check username and password."
  when Net::SSH::ConnectionTimeout
    "Connection timed out. Check host and port, or increase timeout."
  when Net::SSH::HostKeyMismatch
    "Host key verification failed. This may indicate a security issue."
  when Errno::ECONNREFUSED
    "Connection refused. Check if service is running on #{@options[:host]}:#{@options[:port]}"
  when Errno::EHOSTUNREACH
    "Host unreachable. Check network connectivity and host address."
  else
    "Connection failed: #{error.message}"
  end
end
```

### Comprehensive Error Context

```ruby
class DetailedError < StandardError
  attr_reader :context, :retry_suggestion, :documentation_link
  
  def initialize(message, context: {}, retry_suggestion: nil, documentation_link: nil)
    super(message)
    @context = context
    @retry_suggestion = retry_suggestion
    @documentation_link = documentation_link
  end
  
  def detailed_message
    msg = [message]
    msg << "Context: #{context}" unless context.empty?
    msg << "Suggestion: #{retry_suggestion}" if retry_suggestion
    msg << "Documentation: #{documentation_link}" if documentation_link
    msg.join("\n")
  end
end

def handle_connection_error(error)
  detailed_error = case error
  when Net::SSH::AuthenticationFailed
    DetailedError.new(
      "SSH authentication failed",
      context: { host: @options[:host], user: @options[:user] },
      retry_suggestion: "Verify credentials or check if SSH key authentication is required",
      documentation_link: "https://github.com/yourorg/train-yourname#authentication"
    )
  when Errno::ECONNREFUSED
    DetailedError.new(
      "Connection refused",
      context: { host: @options[:host], port: @options[:port] },
      retry_suggestion: "Check if the service is running and the port is correct",
      documentation_link: "https://github.com/yourorg/train-yourname#troubleshooting"
    )
  else
    DetailedError.new(error.message)
  end
  
  @logger.error(detailed_error.detailed_message)
  raise Train::TransportError, detailed_error.detailed_message
end
```

---

## Performance Optimization

### Connection Pooling and Reuse

```ruby
class ConnectionPool
  def initialize(max_size: 5, timeout: 30)
    @pool = Queue.new
    @max_size = max_size
    @timeout = timeout
    @created = 0
    @mutex = Mutex.new
  end
  
  def with_connection(options)
    connection = acquire_connection(options)
    begin
      yield connection
    ensure
      release_connection(connection)
    end
  end
  
  private
  
  def acquire_connection(options)
    @mutex.synchronize do
      if @pool.empty? && @created < @max_size
        @created += 1
        create_new_connection(options)
      else
        @pool.pop(true) rescue create_new_connection(options)
      end
    end
  end
  
  def release_connection(connection)
    @pool.push(connection) if connection&.alive?
  end
end

# Usage in connection class
class Connection
  @@connection_pool = ConnectionPool.new
  
  def run_command_via_connection(cmd)
    @@connection_pool.with_connection(@options) do |conn|
      conn.execute(cmd)
    end
  end
end
```

### Command Batching

```ruby
def run_multiple_commands(commands)
  return commands.map { |cmd| mock_command_result(cmd) } if @options[:mock]
  
  # Batch commands for efficiency
  batch_separator = " && "
  batched_command = commands.join(batch_separator)
  
  begin
    result = execute_command(batched_command)
    
    # Split results back into individual command results
    split_batch_results(result, commands, batch_separator)
  rescue => e
    # Fallback to individual execution if batching fails
    @logger.warn("Batch execution failed, falling back to individual commands: #{e.message}")
    commands.map { |cmd| run_command_via_connection(cmd) }
  end
end

private

def split_batch_results(batch_result, commands, separator)
  # Implementation depends on target system's batch command behavior
  outputs = batch_result.stdout.split(/#{Regexp.escape(separator)}/)
  
  commands.zip(outputs).map do |cmd, output|
    CommandResult.new(output.to_s.strip, 0)
  end
end
```

### Caching Strategies

```ruby
module Cacheable
  def with_cache(key, ttl: 300)
    @cache ||= {}
    @cache_timestamps ||= {}
    
    now = Time.now
    
    if @cache.key?(key) && (now - @cache_timestamps[key]) < ttl
      @logger.debug("Cache hit for: #{key}")
      return @cache[key]
    end
    
    @logger.debug("Cache miss for: #{key}")
    result = yield
    
    @cache[key] = result
    @cache_timestamps[key] = now
    
    result
  end
  
  def clear_cache
    @cache&.clear
    @cache_timestamps&.clear
  end
end

class Connection
  include Cacheable
  
  def get_system_info
    with_cache("system_info", ttl: 600) do
      result = run_command("show version")
      parse_system_info(result.stdout)
    end
  end
  
  def get_interface_list
    with_cache("interfaces", ttl: 60) do
      result = run_command("show interfaces brief")
      parse_interfaces(result.stdout)
    end
  end
end
```

### Lazy Loading and On-Demand Connection

```ruby
def connect
  # Don't connect until actually needed
  @connect_promise ||= create_connection_promise
end

def connected?
  @connect_promise&.fulfilled? && @connection&.alive?
end

def ensure_connected
  return if connected?
  
  @connection = @connect_promise&.value || establish_connection
  configure_session if @connection
end

def run_command_via_connection(cmd)
  ensure_connected
  @connection.execute(cmd)
end

private

def create_connection_promise
  # Use a promise/future pattern for lazy connection
  Thread.new do
    establish_connection
  end
end
```

---

## Security Best Practices

### Credential Handling

```ruby
def initialize(options)
  @options = sanitize_options(options.dup)
  
  # Never log sensitive information
  safe_options = @options.reject { |k, v| sensitive_option?(k) }
  @logger.debug("Connection initialized with options: #{safe_options}")
  
  super(@options)
end

private

def sanitize_options(options)
  # Remove credentials from any logging or error messages
  options.each do |key, value|
    if sensitive_option?(key) && value.is_a?(String)
      # Validate format but don't store in logs
      validate_credential_format(key, value)
    end
  end
  
  options
end

def sensitive_option?(key)
  %i[password api_key token secret access_key private_key].include?(key.to_sym)
end

def validate_credential_format(type, value)
  case type.to_sym
  when :password
    raise Train::ClientError, "Password cannot be empty" if value.empty?
  when :api_key
    raise Train::ClientError, "API key format invalid" unless value.match?(/^[a-zA-Z0-9_-]+$/)
  when :token
    raise Train::ClientError, "Token format invalid" unless value.length >= 20
  end
end
```

### Secure Connection Configuration

```ruby
def secure_ssh_options
  {
    # Security settings
    verify_host_key: @options[:verify_host_key] != false, # Default to true
    encryption: ["aes256-ctr", "aes192-ctr", "aes128-ctr"],
    hmac: ["hmac-sha2-256", "hmac-sha2-512"],
    kex: ["diffie-hellman-group14-sha256", "ecdh-sha2-nistp256"],
    
    # Disable weak algorithms
    compression: false,
    
    # Timeouts
    timeout: @options[:timeout] || 30,
    keepalive: true,
    keepalive_interval: @options[:keepalive_interval] || 60,
    
    # Authentication
    auth_methods: determine_auth_methods,
    keys_only: @options[:keys_only] || false
  }
end

def determine_auth_methods
  methods = []
  methods << "publickey" if @options[:key_files]
  methods << "password" if @options[:password]
  methods << "keyboard-interactive" if @options[:interactive_auth]
  
  # Default to secure methods if none specified
  methods.empty? ? ["publickey", "password"] : methods
end
```

### Input Validation and Sanitization

```ruby
def run_command_via_connection(cmd)
  validated_cmd = validate_and_sanitize_command(cmd)
  execute_command(validated_cmd)
end

private

def validate_and_sanitize_command(cmd)
  # Basic validation
  raise ArgumentError, "Command cannot be nil" if cmd.nil?
  raise ArgumentError, "Command cannot be empty" if cmd.strip.empty?
  raise ArgumentError, "Command too long" if cmd.length > 1000
  
  # Sanitize dangerous patterns
  sanitized = cmd.dup
  
  # Remove or escape dangerous shell metacharacters
  dangerous_patterns = [
    /;\s*rm\s/,           # Command chaining with rm
    /\|\s*rm\s/,          # Piping to rm
    /`[^`]*`/,            # Command substitution
    /\$\([^)]*\)/,        # Command substitution
    />\s*\/dev\/null/,    # Output redirection (might hide evidence)
  ]
  
  dangerous_patterns.each do |pattern|
    if sanitized.match?(pattern)
      @logger.warn("Potentially dangerous command pattern detected: #{pattern}")
      # Could raise error or sanitize based on security policy
    end
  end
  
  sanitized
end

def validate_file_path(path)
  # Prevent directory traversal
  raise ArgumentError, "Invalid file path" if path.include?("..")
  raise ArgumentError, "Absolute paths only" unless path.start_with?("/")
  
  # Whitelist allowed paths based on plugin purpose
  allowed_prefixes = ["/config/", "/status/", "/logs/"]
  unless allowed_prefixes.any? { |prefix| path.start_with?(prefix) }
    raise ArgumentError, "File path not allowed: #{path}"
  end
  
  path
end
```

### Secure Error Handling

```ruby
def handle_authentication_error(error)
  # Don't leak information about valid usernames or account existence
  generic_message = "Authentication failed. Please check your credentials."
  
  # Log detailed information for debugging (not shown to user)
  @logger.error("Authentication failure details: #{error.class} - #{error.message}")
  @logger.error("Host: #{@options[:host]}, User: #{@options[:user]}")
  
  # Return generic error to user
  CommandResult.new("", 1, generic_message)
end

def sanitize_output_for_logging(output)
  # Remove potential sensitive information from logs
  sanitized = output.dup
  
  # Remove common sensitive patterns
  sanitized.gsub!(/password[:\s=]+\S+/i, 'password=***')
  sanitized.gsub!(/secret[:\s=]+\S+/i, 'secret=***')
  sanitized.gsub!(/token[:\s=]+\S+/i, 'token=***')
  sanitized.gsub!(/key[:\s=]+\S+/i, 'key=***')
  
  # Remove potential IP addresses if overly sensitive
  sanitized.gsub!(/\b(?:\d{1,3}\.){3}\d{1,3}\b/, 'x.x.x.x') if @options[:sanitize_ips]
  
  sanitized
end
```

---

## Code Organization

### Modular Architecture

```ruby
# lib/train-yourname/connection.rb
require "train-yourname/connection/ssh_handler"
require "train-yourname/connection/command_executor"
require "train-yourname/connection/file_handler"

class Connection < Train::Plugins::Transport::BaseConnection
  include TrainPlugins::YourName::Platform
  
  def initialize(options)
    @options = options.dup
    @ssh_handler = SSHHandler.new(@options)
    @command_executor = CommandExecutor.new(@ssh_handler, @options)
    @file_handler = FileHandler.new(@command_executor)
    
    super(@options)
  end
  
  def run_command_via_connection(cmd)
    @command_executor.execute(cmd)
  end
  
  def file_via_connection(path)
    @file_handler.handle(path)
  end
end
```

### Configuration Management

```ruby
# lib/train-yourname/config.rb
module TrainPlugins::YourName
  class Config
    DEFAULT_OPTIONS = {
      port: 22,
      timeout: 30,
      keepalive: true,
      keepalive_interval: 60,
      max_retries: 3,
      retry_delay: 2
    }.freeze
    
    REQUIRED_OPTIONS = %i[host user].freeze
    SENSITIVE_OPTIONS = %i[password api_key token].freeze
    
    def self.validate!(options)
      REQUIRED_OPTIONS.each do |option|
        raise Train::ClientError, "#{option} is required" unless options[option]
      end
      
      validate_port(options[:port]) if options[:port]
      validate_timeout(options[:timeout]) if options[:timeout]
    end
    
    def self.with_defaults(options)
      DEFAULT_OPTIONS.merge(options)
    end
    
    private_class_method
    
    def self.validate_port(port)
      port_num = port.to_i
      unless (1..65535).include?(port_num)
        raise Train::ClientError, "Port must be between 1 and 65535"
      end
    end
    
    def self.validate_timeout(timeout)
      timeout_num = timeout.to_i
      unless timeout_num > 0
        raise Train::ClientError, "Timeout must be positive"
      end
    end
  end
end
```

### Consistent Naming Conventions

```ruby
# Use clear, descriptive method names
def generate_bastion_proxy_command    # Good
def gen_proxy_cmd                     # Poor

def extract_version_from_output       # Good  
def get_ver                          # Poor

def validate_connection_options       # Good
def check_opts                       # Poor

# Use consistent parameter naming
def initialize(options)               # Standard
def initialize(opts)                  # Inconsistent

def run_command_via_connection(cmd)   # Train standard
def exec_cmd(command)                 # Inconsistent

# Use clear class organization
module TrainPlugins::YourName
  class Transport                     # Main plugin class
  class Connection                    # Connection implementation
  class Config                       # Configuration management
  module Platform                    # Platform detection
  module Utils                       # Utility functions
end
```

---

## Logging and Debugging

### Structured Logging

```ruby
def setup_logging
  @logger = @options[:logger] || Logger.new(STDOUT)
  @logger.level = determine_log_level
  @logger.formatter = create_log_formatter
end

private

def determine_log_level
  case ENV["TRAIN_LOG_LEVEL"]&.upcase
  when "DEBUG" then Logger::DEBUG
  when "INFO" then Logger::INFO
  when "WARN" then Logger::WARN
  when "ERROR" then Logger::ERROR
  else Logger::WARN
  end
end

def create_log_formatter
  proc do |severity, datetime, progname, msg|
    thread_id = Thread.current.object_id
    "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity} [#{thread_id}] train-yourname: #{msg}\n"
  end
end

# Usage throughout the plugin
def connect
  @logger.info("Establishing connection to #{@options[:host]}:#{@options[:port]}")
  @logger.debug("Connection options: #{@options.reject { |k,v| sensitive_option?(k) }}")
  
  start_time = Time.now
  
  begin
    establish_connection
    duration = Time.now - start_time
    @logger.info("Connection established successfully in #{'%.2f' % duration}s")
  rescue => e
    duration = Time.now - start_time
    @logger.error("Connection failed after #{'%.2f' % duration}s: #{e.message}")
    raise
  end
end
```

### Debug Mode Support

```ruby
def run_command_via_connection(cmd)
  if debug_mode?
    @logger.debug("Executing command: #{cmd}")
    @logger.debug("Connection state: #{connection_debug_info}")
  end
  
  start_time = Time.now
  result = execute_command(cmd)
  duration = Time.now - start_time
  
  if debug_mode?
    @logger.debug("Command completed in #{'%.3f' % duration}s")
    @logger.debug("Exit status: #{result.exit_status}")
    @logger.debug("Output size: #{result.stdout.bytesize} bytes")
    
    if result.exit_status != 0
      @logger.debug("Error output: #{result.stderr}")
    end
  end
  
  result
end

private

def debug_mode?
  @options[:debug] || ENV["TRAIN_DEBUG"] == "true"
end

def connection_debug_info
  {
    connected: connected?,
    host: @options[:host],
    port: @options[:port],
    proxy: @options[:bastion_host] ? "via #{@options[:bastion_host]}" : "direct"
  }
end
```

### Performance Monitoring

```ruby
module PerformanceMonitoring
  def with_timing(operation)
    start_time = Time.now
    result = yield
    duration = Time.now - start_time
    
    log_performance_metric(operation, duration)
    
    result
  end
  
  private
  
  def log_performance_metric(operation, duration)
    @performance_metrics ||= {}
    @performance_metrics[operation] ||= []
    @performance_metrics[operation] << duration
    
    # Log slow operations
    if duration > performance_threshold(operation)
      @logger.warn("Slow #{operation}: #{'%.3f' % duration}s")
    end
    
    # Periodic performance summary
    if @performance_metrics[operation].length % 100 == 0
      log_performance_summary(operation)
    end
  end
  
  def performance_threshold(operation)
    case operation
    when :connect then 10.0
    when :command then 5.0
    when :file_read then 2.0
    else 1.0
    end
  end
  
  def log_performance_summary(operation)
    metrics = @performance_metrics[operation]
    avg = metrics.sum / metrics.length
    max = metrics.max
    min = metrics.min
    
    @logger.info("Performance summary for #{operation}: avg=#{'%.3f' % avg}s, min=#{'%.3f' % min}s, max=#{'%.3f' % max}s")
  end
end

class Connection
  include PerformanceMonitoring
  
  def connect
    with_timing(:connect) { establish_connection }
  end
  
  def run_command_via_connection(cmd)
    with_timing(:command) { execute_command(cmd) }
  end
end
```

---

## Cross-Platform Considerations

### Windows vs Unix Path Handling

```ruby
def normalize_file_path(path)
  case @platform_family
  when "windows"
    # Convert Unix-style paths to Windows style
    path.gsub("/", "\\").gsub(/^\\/, "C:\\")
  when "unix", "linux"
    # Ensure Unix-style paths
    path.gsub("\\", "/")
  else
    # Default to input path
    path
  end
end

def file_via_connection(path)
  normalized_path = normalize_file_path(path)
  
  case @platform_family
  when "windows"
    WindowsFileHandler.new(self, normalized_path)
  else
    UnixFileHandler.new(self, normalized_path)
  end
end
```

### Command Syntax Adaptation

```ruby
def adapt_command_for_platform(cmd)
  case @platform_family
  when "windows"
    adapt_for_windows(cmd)
  when "network"
    adapt_for_network_device(cmd)
  else
    cmd  # Assume Unix-like by default
  end
end

private

def adapt_for_windows(cmd)
  # Convert common Unix commands to Windows equivalents
  case cmd
  when /^ls\s*(.*)/
    "dir #{$1}".strip
  when /^cat\s+(.+)/
    "type #{$1}"
  when /^grep\s+(.+)/
    "findstr #{$1}"
  else
    cmd
  end
end

def adapt_for_network_device(cmd)
  # Add device-specific command prefixes or modifications
  case cmd
  when /^show/
    cmd  # Already in correct format
  when /^get\s+(.+)/
    "show #{$1}"  # Convert generic get to show
  else
    cmd
  end
end
```

### Platform-Specific Features

```ruby
class Connection
  def initialize(options)
    super(options)
    @platform_capabilities = detect_platform_capabilities
  end
  
  def supports_feature?(feature)
    @platform_capabilities.include?(feature)
  end
  
  def run_command_via_connection(cmd)
    if supports_feature?(:json_output) && @options[:prefer_json]
      cmd = "#{cmd} | format json" unless cmd.include?("json")
    end
    
    execute_command(cmd)
  end
  
  private
  
  def detect_platform_capabilities
    capabilities = [:basic_commands]
    
    # Test for advanced features
    capabilities << :json_output if test_json_support
    capabilities << :batch_commands if test_batch_support
    capabilities << :streaming if test_streaming_support
    
    capabilities
  end
  
  def test_json_support
    return false if @options[:mock]
    
    begin
      result = execute_command("show version | format json")
      JSON.parse(result.stdout)
      true
    rescue
      false
    end
  end
end
```

---

## Maintenance and Evolution

### Backward Compatibility

```ruby
module TrainPlugins::YourName
  # Maintain deprecated methods with warnings
  def old_method_name(*args)
    warn_deprecation("old_method_name", "new_method_name", "2.0.0")
    new_method_name(*args)
  end
  
  private
  
  def warn_deprecation(old_method, new_method, removal_version)
    message = "DEPRECATION WARNING: #{old_method} is deprecated and will be removed in version #{removal_version}. Use #{new_method} instead."
    
    if defined?(ActiveSupport::Deprecation)
      ActiveSupport::Deprecation.warn(message)
    else
      warn(message)
    end
  end
end

# Version-based feature flags
class Connection
  def initialize(options)
    super(options)
    @api_version = determine_api_version
  end
  
  private
  
  def determine_api_version
    major_version = TrainPlugins::YourName::VERSION.split('.').first.to_i
    
    case major_version
    when 1
      :v1
    when 2
      :v2
    else
      :latest
    end
  end
  
  def feature_available?(feature)
    case @api_version
    when :v1
      [:basic_connection, :simple_commands].include?(feature)
    when :v2
      [:basic_connection, :simple_commands, :proxy_support, :advanced_auth].include?(feature)
    else
      true  # Latest version supports everything
    end
  end
end
```

### Configuration Migration

```ruby
def migrate_legacy_options(options)
  migrations = {
    # Old option => new option
    :hostname => :host,
    :username => :user,
    :ssh_port => :port,
    :proxy_host => :bastion_host,
    :proxy_user => :bastion_user
  }
  
  migrated_options = options.dup
  
  migrations.each do |old_key, new_key|
    if migrated_options.key?(old_key) && !migrated_options.key?(new_key)
      warn "Option '#{old_key}' is deprecated, use '#{new_key}' instead"
      migrated_options[new_key] = migrated_options.delete(old_key)
    end
  end
  
  migrated_options
end
```

### Extension Points

```ruby
module TrainPlugins::YourName
  # Plugin registry for extensions
  class PluginRegistry
    @plugins = {}
    
    def self.register(name, plugin_class)
      @plugins[name] = plugin_class
    end
    
    def self.get(name)
      @plugins[name]
    end
    
    def self.all
      @plugins
    end
  end
  
  # Base class for extensions
  class Extension
    def initialize(connection)
      @connection = connection
    end
    
    def before_command(cmd)
      cmd  # Override in subclasses
    end
    
    def after_command(result)
      result  # Override in subclasses
    end
  end
end

# Usage in connection
class Connection
  def initialize(options)
    super(options)
    @extensions = load_extensions
  end
  
  def run_command_via_connection(cmd)
    # Apply extensions
    processed_cmd = @extensions.reduce(cmd) { |c, ext| ext.before_command(c) }
    result = execute_command(processed_cmd)
    @extensions.reduce(result) { |r, ext| ext.after_command(r) }
  end
  
  private
  
  def load_extensions
    extension_names = @options[:extensions] || []
    extension_names.map do |name|
      extension_class = PluginRegistry.get(name)
      extension_class&.new(self)
    end.compact
  end
end
```

---

## Production Deployment

### Health Checks

```ruby
def health_check
  {
    status: overall_health_status,
    connection: connection_health,
    performance: performance_health,
    last_check: Time.now.iso8601
  }
end

private

def overall_health_status
  checks = [connection_health, performance_health]
  
  return :critical if checks.any? { |check| check[:status] == :critical }
  return :warning if checks.any? { |check| check[:status] == :warning }
  :healthy
end

def connection_health
  return { status: :critical, message: "Not connected" } unless connected?
  
  begin
    result = run_command("echo 'health check'")
    if result.exit_status == 0
      { status: :healthy, response_time: last_command_duration }
    else
      { status: :warning, message: "Command failed with status #{result.exit_status}" }
    end
  rescue => e
    { status: :critical, message: "Health check failed: #{e.message}" }
  end
end

def performance_health
  return { status: :healthy } unless @performance_metrics
  
  recent_commands = @performance_metrics[:command]&.last(10) || []
  return { status: :healthy } if recent_commands.empty?
  
  avg_duration = recent_commands.sum / recent_commands.length
  
  case
  when avg_duration > 10.0
    { status: :critical, message: "Average command duration too high: #{'%.2f' % avg_duration}s" }
  when avg_duration > 5.0
    { status: :warning, message: "Average command duration elevated: #{'%.2f' % avg_duration}s" }
  else
    { status: :healthy, avg_duration: avg_duration }
  end
end
```

### Resource Management

```ruby
def finalize
  cleanup_resources
  close_connections
  clear_caches
end

private

def cleanup_resources
  # Clean up temporary files
  @temp_files&.each do |file|
    File.delete(file) if File.exist?(file)
  end
  
  # Clear sensitive data from memory
  @options[:password] = nil if @options[:password]
  @options[:api_key] = nil if @options[:api_key]
  
  # Cancel background threads
  @background_threads&.each(&:kill)
end

def close_connections
  @ssh_session&.close
  @connection_pool&.close_all
end

def clear_caches
  @cache&.clear
  @performance_metrics&.clear
end

# Ensure cleanup on exit
at_exit { finalize }

# Handle signals gracefully
Signal.trap("TERM") { finalize; exit }
Signal.trap("INT") { finalize; exit }
```

---

## Key Takeaways

1. **Fail gracefully** - Handle errors without breaking InSpec workflows
2. **Optimize for performance** - Use connection pooling, caching, and batching
3. **Security first** - Sanitize inputs, secure credentials, validate everything
4. **Modular design** - Separate concerns for maintainability
5. **Comprehensive logging** - Enable debugging and performance monitoring
6. **Cross-platform support** - Handle platform differences gracefully
7. **Plan for evolution** - Support deprecation, migration, and extensions
8. **Production readiness** - Include health checks and resource management

**Next**: Learn about [Troubleshooting](11-troubleshooting.md) common plugin development issues.
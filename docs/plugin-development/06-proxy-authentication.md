# Proxy and Authentication

Implementing enterprise-ready proxy/bastion support and authentication patterns for production Train plugins.

## Table of Contents

1. [Why Enterprise Features Matter](#why-enterprise-features-matter)
2. [Command Execution Security](#command-execution-security)
3. [Two Implementation Approaches](#two-implementation-approaches)
4. [Train Standard SSH Transport (Recommended)](#train-standard-ssh-transport-recommended)
5. [Custom SSH Implementation (Advanced)](#custom-ssh-implementation-advanced)
6. [Bastion Host Configuration](#bastion-host-configuration)
7. [Environment Variable Support](#environment-variable-support)
8. [Testing and Validation](#testing-and-validation)

---

## Why Enterprise Features Matter

Enterprise environments rarely allow direct connections to infrastructure devices. Instead, they use:

- **Jump hosts/Bastion hosts** - Centralized access points for security
- **Proxy commands** - Custom routing through security infrastructure
- **Multi-factor authentication** - Complex credential management
- **Network segmentation** - Isolated network zones requiring tunneling

**Without proxy support, your plugin won't work in production environments.**

### Common Enterprise Patterns

```bash
# Corporate network with dedicated jump host
inspec exec profile -t "yourname://admin@internal.device?bastion_host=jump.corp.com"

# Cloud environment with bastion instance
inspec exec profile -t "yourname://user@10.0.1.100?bastion_host=bastion.aws.company.com"

# Custom proxy for complex routing
inspec shell -t "yourname://admin@device?proxy_command=ssh%20jump%20-W%20%h:%p"

# Multi-hop through DMZ
inspec detect -t "yourname://operator@firewall.dmz?bastion_host=jump.dmz.corp"
```

---

## Command Execution Security

⚠️ **CRITICAL**: InSpec's `run_command` must execute on the TARGET device, never on the proxy/jump host or InSpec host.

### Security Verification

```ruby
# ✅ CORRECT: Commands execute on TARGET device
@ssh_session = Net::SSH.start(
  "target.device.com",     # TARGET device
  "admin",                 # User on TARGET device
  proxy: proxy_jump        # Tunnel through jump host
)
result = @ssh_session.exec!("show version")  # Executes on target.device.com

# ❌ WRONG: Commands execute on jump host  
@jump_session = Net::SSH.start("jump.host.com", "user")
result = @jump_session.exec!("show version")  # Executes on jump.host.com (SECURITY RISK!)
```

### How Proxy Tunneling Works

1. **First hop**: InSpec host → Jump host (authentication)
2. **Second hop**: Jump host → Target device (forwarded connection)
3. **Final session**: Encrypted tunnel directly to target device
4. **Command execution**: All commands run on target device
5. **Result tunneling**: Output travels back through jump host to InSpec

### Verification Your Implementation Is Correct

```ruby
# Test that commands execute on target device
def verify_target_execution
  result = connection.run_command("hostname")
  # Should return target device hostname, NOT jump host hostname
  
  platform_result = connection.run_command("show version")  
  # Should return device-specific output (JunOS, IOS, etc.)
  # NOT Linux/Unix output from jump host
end
```

---

## Two Implementation Approaches

You have two main approaches for implementing proxy support in Train plugins:

### 🟢 **Approach 1: Use Train's Built-in SSH Transport (Recommended)**

**Pros:**
- ✅ Leverages existing, well-tested Train SSH implementation
- ✅ Automatic proxy support with no custom code needed
- ✅ Standard Train options work out-of-the-box
- ✅ Less code to maintain and debug

**Cons:**
- ❌ Less control over SSH connection details
- ❌ May not support device-specific authentication flows
- ❌ Limited customization for device-specific SSH options

**When to use:** For most network devices with standard SSH behavior.

### 🟡 **Approach 2: Custom SSH Implementation (Advanced)**

**Pros:**
- ✅ Full control over SSH connection lifecycle
- ✅ Support for device-specific authentication patterns
- ✅ Custom prompt handling and session configuration
- ✅ Fine-grained SSH option control

**Cons:**  
- ❌ More complex code to implement and maintain
- ❌ Must handle proxy authentication manually
- ❌ Higher risk of SSH-related bugs

**When to use:** When you need device-specific SSH behavior (like Juniper CLI configuration, Cisco enable mode, custom prompts).

---

## Train Standard SSH Transport (Recommended)

For most plugins, use Train's existing SSH transport with proxy support.

### Implementation Pattern

```ruby
# In connection.rb
class Connection < Train::Plugins::Transport::BaseConnection
  
  def initialize(options)
    @options = options
    super(@options)
    
    # Let Train handle SSH and proxy complexity
    connect unless @options[:mock]
  end
  
  private
  
  def connect
    # Create SSH transport with all options passed through
    @train_ssh = Train.create('ssh', @options)
    @ssh_connection = @train_ssh.connection
  end
  
  def run_command_via_connection(cmd)
    # Delegate to Train's SSH implementation
    @ssh_connection.run_command(cmd)
  end
end
```

### Standard Train Options Work Automatically

All Train standard proxy options work automatically when using this approach:
- `bastion_host`, `bastion_user`, `bastion_port`
- `proxy_command` 
- `key_files`, `keys_only`

No additional proxy code needed in your plugin!

---

## Custom SSH Implementation (Advanced)

When you need device-specific SSH behavior, implement custom SSH with manual proxy support.

### Why Juniper Plugin Uses Custom SSH

The train-juniper plugin uses custom SSH implementation because:

1. **Device-specific CLI configuration**: JunOS needs `set cli screen-length 0`
2. **Custom prompt patterns**: Juniper uses `[%>$#]` prompts vs standard shell prompts  
3. **SSH_ASKPASS automation**: Non-interactive bastion password authentication
4. **Session optimization**: Juniper-specific keepalive and timeout settings

### Custom Implementation Pattern

```ruby
# In connection.rb
class Connection < Train::Plugins::Transport::BaseConnection
  
  def initialize(options)
    @options = options
    super(@options)
    
    # Custom SSH implementation for device-specific needs
    connect unless @options[:mock]
  end
  
  private
  
  def connect
    require 'net/ssh'
    
    ssh_options = {
      port: @options[:port] || 22,
      password: @options[:password],
      timeout: @options[:timeout] || 30,
      verify_host_key: :never
    }
    
    # Add bastion support with SSH_ASKPASS automation
    if @options[:bastion_host]
      setup_bastion_proxy(ssh_options)
    end
    
    # Connect to TARGET device (not jump host!)
    @ssh_session = Net::SSH.start(@options[:host], @options[:user], ssh_options)
    
    # Device-specific session configuration
    configure_device_session
  end
  
  def setup_bastion_proxy(ssh_options)
    require 'net/ssh/proxy/jump'
    
    # Build proxy jump string
    bastion_user = @options[:bastion_user] || 'root'
    bastion_port = @options[:bastion_port] || 22
    
    proxy_jump = if bastion_port == 22
      "#{bastion_user}@#{@options[:bastion_host]}"
    else
      "#{bastion_user}@#{@options[:bastion_host]}:#{bastion_port}"
    end
    
    # Automated password authentication via SSH_ASKPASS
    bastion_password = @options[:bastion_password] || @options[:password]
    if bastion_password
      @ssh_askpass_script = create_ssh_askpass_script(bastion_password)
      ENV['SSH_ASKPASS'] = @ssh_askpass_script
      ENV['SSH_ASKPASS_REQUIRE'] = 'force'
    end
    
    # CRITICAL: This creates tunnel to TARGET device, not jump host
    ssh_options[:proxy] = Net::SSH::Proxy::Jump.new(proxy_jump)
  end
  
  def configure_device_session
    # Juniper-specific CLI optimization
    @ssh_session.exec!('set cli screen-length 0')
    @ssh_session.exec!('set cli screen-width 0')
    @ssh_session.exec!('set cli complete-on-space off')
  end
  
  def run_command_via_connection(cmd)
    # Execute on TARGET device through proxy tunnel
    output = @ssh_session.exec!(cmd)
    format_device_result(output, cmd)
  end
end
```

### Train Standard Proxy Options

When implementing custom SSH, support these standard Train options for consistency:

```ruby
# In transport.rb
class Transport < Train.plugin(1)
  name "yourname"
  
  # Basic connection options
  option :host, required: true
  option :port, default: 22
  option :user, required: true
  option :password, default: nil
  
  # Train standard proxy options
  option :bastion_host, default: nil
  option :bastion_user, default: "root"
  option :bastion_port, default: 22
  option :bastion_password, default: nil
  option :proxy_command, default: nil
  
  # SSH key authentication
  option :key_files, default: nil
  option :keys_only, default: false
end
```

### Critical Rule: Mutual Exclusion

**Cannot use both `bastion_host` and `proxy_command` simultaneously** - this is enforced by Train's SSH transport and should be enforced by your plugin.

```ruby
# In connection.rb initialize()
def validate_proxy_options
  if @options[:bastion_host] && @options[:proxy_command]
    raise Train::ClientError, "Cannot specify both bastion_host and proxy_command"
  end
end
```

---

## Bastion Host Implementation

Bastion hosts are the most common enterprise proxy pattern. Users specify a jump host, and your plugin generates the appropriate SSH proxy command.

### Transport Options Setup

```ruby
# In transport.rb
option :bastion_host, default: nil
option :bastion_user, default: "root"
option :bastion_port, default: 22
```

### Connection Implementation

```ruby
# In connection.rb
def initialize(options)
  @options = options.dup
  
  # Handle bastion environment variables
  @options[:bastion_host] ||= ENV['YOUR_BASTION_HOST']
  @options[:bastion_user] ||= ENV['YOUR_BASTION_USER'] || 'root'
  @options[:bastion_port] ||= ENV['YOUR_BASTION_PORT']&.to_i || 22
  
  # Map bastion_host to proxy_jump for compatibility
  if @options[:bastion_host] && !@options[:proxy_jump]
    @options[:proxy_jump] = "#{@options[:bastion_user]}@#{@options[:bastion_host]}"
  end
  
  # Validate proxy configuration
  validate_proxy_options
  
  super(@options)
  connect unless @options[:mock]
end

def connect
  ssh_options = base_ssh_options
  
  # Add proxy support if configured using Net::SSH::Proxy::Jump
  if @options[:proxy_jump]
    require 'net/ssh/proxy/jump'
    
    # Set up automated password authentication via SSH_ASKPASS
    if @options[:proxy_password]
      @ssh_askpass_script = create_ssh_askpass_script(@options[:proxy_password])
      ENV['SSH_ASKPASS'] = @ssh_askpass_script
      ENV['SSH_ASKPASS_REQUIRE'] = 'force'
      @logger.debug("Configured SSH_ASKPASS for automated proxy authentication")
    end
    
    ssh_options[:proxy] = Net::SSH::Proxy::Jump.new(@options[:proxy_jump])
    @logger.debug("Using proxy jump: #{@options[:proxy_jump]}")
  end
  
  @ssh_session = Net::SSH.start(@options[:host], @options[:user], ssh_options)
end

private

def create_ssh_askpass_script(password)
  require 'tempfile'
  
  script = Tempfile.new(['ssh_askpass', '.sh'])
  script.write("#!/bin/bash\necho '#{password}'\n")
  script.close
  File.chmod(0755, script.path)
  
  @logger.debug("Created SSH_ASKPASS script at #{script.path}")
  script.path
end
```

### Modern Proxy Jump vs Legacy ProxyCommand

**Recommended: Use `proxy_jump` with automated password authentication**

```ruby
# Modern approach with SSH_ASKPASS automation
options[:proxy_jump] = "user@bastion.host"
options[:proxy_password] = "password"  # Automated via SSH_ASKPASS

# This creates: Net::SSH::Proxy::Jump.new("user@bastion.host")
# With SSH_ASKPASS script for non-interactive password input
```

**Legacy: ProxyCommand has password authentication limitations**

```ruby
# Legacy approach - cannot handle interactive passwords
proxy_command = "ssh user@bastion.host -W %h:%p"
Net::SSH::Proxy::Command.new(proxy_command)

# ProxyCommand subprocesses cannot access terminal for password prompts
# Only works with SSH keys or SSH agent authentication
```

### URI Examples

```bash
# Modern proxy jump with password
yourname://admin@device.internal?proxy_jump=user@jump.corp.com&proxy_password=secret

# Legacy bastion host (mapped to proxy_jump internally)
yourname://admin@device.internal?bastion_host=jump.corp.com&bastion_user=netops

# With SSH keys (works with both approaches)
yourname://admin@device?proxy_jump=user@jump.corp&key_files=/path/to/key
```

---

## Custom Proxy Commands

For complex network routing scenarios, users can specify custom SSH proxy commands.

### Implementation

```ruby
# In connection.rb
def setup_proxy_connection
  # Handle bastion host
  if @options[:bastion_host]
    proxy_command = generate_bastion_proxy_command
    require 'net/ssh/proxy/command'
    return Net::SSH::Proxy::Command.new(proxy_command)
  end
  
  # Handle custom proxy command
  if @options[:proxy_command]
    @logger.debug("Using custom proxy command: #{@options[:proxy_command]}")
    require 'net/ssh/proxy/command'
    return Net::SSH::Proxy::Command.new(@options[:proxy_command])
  end
  
  # No proxy needed
  nil
end
```

### URI Examples

```bash
# SSH ProxyCommand syntax
yourname://admin@device?proxy_command=ssh%20jump.host%20-W%20%h:%p

# Multi-hop proxy
yourname://admin@device?proxy_command=ssh%20-J%20jump1,jump2%20-W%20%h:%p

# Custom routing with netcat
yourname://admin@device?proxy_command=ssh%20jump%20nc%20%h%20%p

# Complex corporate routing
yourname://admin@device?proxy_command=ssh%20-o%20StrictHostKeyChecking=no%20jump%20-W%20%h:%p
```

**Note**: Users must URL-encode spaces (%20) and other special characters in proxy commands.

---

## Authentication Patterns

### SSH Key Authentication

```ruby
# In transport.rb
option :key_files, default: nil
option :keys_only, default: false

# In connection.rb
def base_ssh_options
  options = {
    port: @options[:port],
    password: @options[:password],
    timeout: @options[:timeout] || 30,
    verify_host_key: :never
  }
  
  # Add SSH key authentication
  if @options[:key_files]
    options[:keys] = Array(@options[:key_files])
    options[:keys_only] = @options[:keys_only]
  end
  
  options
end
```

### API Token Authentication

```ruby
# In transport.rb
option :api_token, default: nil
option :auth_type, default: :token

# In connection.rb
def setup_authentication
  case @options[:auth_type]
  when :token
    @auth_header = "Bearer #{@options[:api_token]}"
  when :basic
    @auth_header = basic_auth_header
  when :custom
    @auth_header = @options[:auth_header]
  end
end

def basic_auth_header
  credentials = Base64.strict_encode64("#{@options[:user]}:#{@options[:password]}")
  "Basic #{credentials}"
end
```

### Multi-Factor Authentication

```ruby
# In transport.rb  
option :mfa_token, default: nil
option :mfa_prompt, default: false

# In connection.rb
def authenticate_with_mfa
  if @options[:mfa_prompt] && !@options[:mfa_token]
    print "Enter MFA token: "
    @options[:mfa_token] = $stdin.gets.chomp
  end
  
  # Use MFA token in authentication
  authenticate_user(@options[:user], @options[:password], @options[:mfa_token])
end
```

---

## Environment Variable Support

Support environment variables for all authentication and proxy options:

### Standard Pattern

```ruby
def initialize(options)
  @options = options.dup
  
  # Basic connection environment variables
  @options[:host] ||= ENV['YOUR_HOST']
  @options[:user] ||= ENV['YOUR_USER']
  @options[:password] ||= ENV['YOUR_PASSWORD']
  @options[:port] ||= ENV['YOUR_PORT']&.to_i || default_port
  
  # Proxy environment variables  
  @options[:bastion_host] ||= ENV['YOUR_BASTION_HOST']
  @options[:bastion_user] ||= ENV['YOUR_BASTION_USER'] || 'root'
  @options[:bastion_port] ||= ENV['YOUR_BASTION_PORT']&.to_i || 22
  @options[:proxy_command] ||= ENV['YOUR_PROXY_COMMAND']
  
  # Modern proxy jump environment variables
  @options[:proxy_jump] ||= ENV['YOUR_PROXY_JUMP']
  @options[:proxy_password] ||= ENV['YOUR_PROXY_PASSWORD']
  
  # Authentication environment variables
  @options[:api_token] ||= ENV['YOUR_API_TOKEN']
  @options[:key_files] ||= ENV['YOUR_KEY_FILES']&.split(',')
  
  # Override explicit options take precedence
  super(@options)
end
```

### Environment Variable Naming

Follow these conventions:
- `YOUR_HOST`, `YOUR_USER`, `YOUR_PASSWORD` - Basic connection
- `YOUR_BASTION_HOST`, `YOUR_BASTION_USER` - Proxy configuration
- `YOUR_API_TOKEN`, `YOUR_KEY_FILES` - Authentication
- `YOUR_TIMEOUT`, `YOUR_PORT` - Connection tuning

### Usage Examples

```bash
# Basic connection via environment
export YOUR_HOST=device.corp.com
export YOUR_USER=admin
export YOUR_PASSWORD=secret
inspec detect -t yourname://

# Proxy configuration via environment
export YOUR_BASTION_HOST=jump.corp.com
export YOUR_BASTION_USER=netops
inspec detect -t yourname://admin@internal.device

# Mixed explicit and environment
export YOUR_BASTION_HOST=jump.corp.com
inspec detect -t yourname://admin@device.corp?user=different-user
```

---

## Real-World Enterprise Scenarios

### Corporate Network with DMZ

```bash
# Production environment access
inspec exec stig-profile \
  -t "yourname://svc_inspec@prod-firewall.internal.corp?bastion_host=prod-jump.dmz.corp&bastion_user=automation"

# Development environment access  
inspec exec dev-profile \
  -t "yourname://admin@dev-switch.lab.corp?bastion_host=dev-jump.lab.corp"
```

### Cloud Environment with Bastion

```bash
# AWS with bastion instance
inspec exec aws-profile \
  -t "yourname://ubuntu@10.0.1.100?bastion_host=bastion.aws.company.com&bastion_port=2222&key_files=/path/to/aws-key.pem"

# Azure with jump host
inspec exec azure-profile \
  -t "yourname://azureuser@10.1.1.100?bastion_host=jump.azure.company.com&bastion_user=automation"
```

### Multi-Region Deployment

```bash
# US East region
US_BASTION=us-east-jump.corp.com inspec exec profile -t yourname://admin@us-east-device

# EU region  
EU_BASTION=eu-west-jump.corp.com inspec exec profile -t yourname://admin@eu-west-device

# Asia Pacific region
APAC_BASTION=apac-jump.corp.com inspec exec profile -t yourname://admin@apac-device
```

---

## Testing Proxy Configurations

### Mock Mode Testing

```ruby
# In test/integration/proxy_test.rb
describe "Proxy Configuration" do
  
  it "should accept bastion host configuration" do
    connection = create_connection({
      host: "internal.device",
      user: "admin",
      bastion_host: "jump.corp.com",
      bastion_user: "netops",
      mock: true
    })
    
    options = connection.instance_variable_get(:@options)
    _(options[:bastion_host]).must_equal("jump.corp.com")
    _(options[:bastion_user]).must_equal("netops")
  end
  
  it "should generate correct bastion proxy command" do
    connection = create_connection({
      host: "device.internal",
      user: "admin",
      bastion_host: "jump.example.com",
      bastion_user: "netadmin",
      bastion_port: 2222,
      mock: true
    })
    
    proxy_command = connection.send(:generate_bastion_proxy_command)
    
    _(proxy_command).must_match(/ssh/)
    _(proxy_command).must_match(/netadmin@jump.example.com/)
    _(proxy_command).must_match(/-p 2222/)
    _(proxy_command).must_match(/-W %h:%p/)
  end
  
  it "should reject conflicting proxy options" do
    _(-> {
      create_connection({
        host: "device.local",
        user: "admin",
        bastion_host: "jump.host",
        proxy_command: "ssh proxy -W %h:%p",
        mock: true
      })
    }).must_raise(Train::ClientError)
  end
end
```

### URI Parsing Tests

```ruby
describe "URI Parsing with Proxy" do
  
  it "should parse bastion host from URI" do
    uri = "yourname://admin@device.local?bastion_host=jump.host&bastion_user=netadmin"
    config = Train.target_config(target: uri)
    
    _(config[:backend]).must_equal("yourname")
    _(config[:bastion_host]).must_equal("jump.host")
    _(config[:bastion_user]).must_equal("netadmin")
  end
  
  it "should parse proxy command from URI" do
    proxy_cmd = "ssh%20jump%20-W%20%25h:%25p"
    uri = "yourname://admin@device.local?proxy_command=#{proxy_cmd}"
    config = Train.target_config(target: uri)
    
    _(config[:proxy_command]).must_equal("ssh jump -W %h:%p")
  end
end
```

### Environment Variable Tests

```ruby
describe "Environment Variable Support" do
  
  before do
    # Clean environment
    %w[YOUR_HOST YOUR_USER YOUR_BASTION_HOST].each { |var| ENV.delete(var) }
  end
  
  after do
    # Clean environment
    %w[YOUR_HOST YOUR_USER YOUR_BASTION_HOST].each { |var| ENV.delete(var) }
  end
  
  it "should use environment variables for proxy" do
    ENV['YOUR_BASTION_HOST'] = 'env.jump.host'
    ENV['YOUR_BASTION_USER'] = 'envuser'
    
    connection = create_connection({ host: "device", user: "admin", mock: true })
    options = connection.instance_variable_get(:@options)
    
    _(options[:bastion_host]).must_equal('env.jump.host')
    _(options[:bastion_user]).must_equal('envuser')
  end
  
  it "should prioritize explicit options over environment" do
    ENV['YOUR_BASTION_HOST'] = 'env.jump.host'
    
    connection = create_connection({
      host: "device",
      user: "admin", 
      bastion_host: "explicit.jump.host",
      mock: true
    })
    
    options = connection.instance_variable_get(:@options)
    _(options[:bastion_host]).must_equal('explicit.jump.host')
  end
end
```

---

## Advanced Proxy Patterns

### SSH Agent Forwarding

```ruby
def generate_bastion_proxy_command
  args = ['ssh']
  
  # Enable SSH agent forwarding if requested
  args += ['-A'] if @options[:forward_agent]
  
  # Standard security options
  args += ['-o', 'UserKnownHostsFile=/dev/null']
  args += ['-o', 'StrictHostKeyChecking=no']
  
  # Connection details
  args += ["#{@options[:bastion_user]}@#{@options[:bastion_host]}"]
  args += ['-p', @options[:bastion_port].to_s]
  args += ['-W', '%h:%p']
  
  args.join(' ')
end
```

### Connection Multiplexing

```ruby
def generate_bastion_proxy_command
  args = ['ssh']
  
  # Enable connection multiplexing for performance
  if @options[:multiplex]
    control_path = "/tmp/train_#{@options[:bastion_host]}_#{@options[:bastion_user]}"
    args += ['-o', "ControlMaster=auto"]
    args += ['-o', "ControlPath=#{control_path}"]
    args += ['-o', "ControlPersist=300"]
  end
  
  # Rest of proxy command...
end
```

### Proxy Chain Support

```ruby
def setup_proxy_chain
  return nil unless @options[:proxy_chain]
  
  # Build multi-hop SSH command
  hops = @options[:proxy_chain].split(',')
  jump_list = hops.join(',')
  
  proxy_command = "ssh -J #{jump_list} -W %h:%p"
  
  require 'net/ssh/proxy/command'
  Net::SSH::Proxy::Command.new(proxy_command)
end
```

---

## Key Takeaways

1. **Enterprise proxy support is mandatory** - Production environments require jump hosts
2. **Follow Train standards** - Use `bastion_host` and `proxy_command` options consistently
3. **Validate configurations** - Enforce mutual exclusion of proxy options
4. **Support environment variables** - Essential for automation and CI/CD
5. **Test thoroughly** - Mock mode, URI parsing, and real proxy scenarios
6. **Document real examples** - Show actual enterprise usage patterns

**Next**: Learn about [Platform Detection](07-platform-detection.md) strategies.
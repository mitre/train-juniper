# Real-World Examples

Complete plugin implementations showcasing different patterns, architectures, and use cases from the Train ecosystem.

## Table of Contents

1. [Network Device Plugin (train-juniper)](#network-device-plugin-train-juniper)
2. [API-Based Plugin (train-rest)](#api-based-plugin-train-rest)
3. [Cloud Service Plugin (train-awsssm)](#cloud-service-plugin-train-awsssm)
4. [Container Platform Plugin (train-k8s-container)](#container-platform-plugin-train-k8s-container)
5. [Windows Automation Plugin (train-pwsh)](#windows-automation-plugin-train-pwsh)
6. [Simple Learning Plugin (train-local-rot13)](#simple-learning-plugin-train-local-rot13)
7. [Plugin Comparison Matrix](#plugin-comparison-matrix)
8. [Architecture Patterns](#architecture-patterns)

---

## Network Device Plugin (train-juniper)

**Repository**: https://github.com/mitre/train-juniper  
**Pattern**: SSH-based network device automation  
**Maintained by**: MITRE SAF Team

### Key Implementation Details

```ruby
# lib/train-juniper/connection.rb - Real implementation
class Connection < Train::Plugins::Transport::BaseConnection
  include TrainPlugins::Juniper::Platform

  def initialize(options)
    @options = options.dup
    @options[:logger] ||= Logger.new($stdout, level: :fatal)
    
    # Environment variable support
    @options[:host] ||= ENV['JUNIPER_HOST']
    @options[:user] ||= ENV['JUNIPER_USER']
    @options[:password] ||= ENV['JUNIPER_PASSWORD']
    
    # Proxy/bastion support (Train standard)
    @options[:bastion_host] ||= ENV['JUNIPER_BASTION_HOST']
    @options[:bastion_user] ||= ENV['JUNIPER_BASTION_USER'] || 'root'
    
    super(@options)
  end

  def run_command_via_connection(cmd)
    return mock_command_result(cmd) if @options[:mock]
    
    session.cmd(cmd)
  rescue => e
    CommandResult.new('', 1, e.message)
  end

  private

  def session
    @session ||= establish_session
  end

  def establish_session
    require 'net/ssh/telnet'
    
    ssh_options = {
      password: @options[:password],
      port: @options[:port] || 22,
      timeout: @options[:timeout] || 30
    }
    
    # Handle proxy connections
    if @options[:bastion_host]
      ssh_options[:proxy] = build_ssh_proxy
    end
    
    Net::SSH::Telnet.new(@options[:host], @options[:user], ssh_options)
  end
end
```

### Unique Characteristics

- **SSH with Telnet layer**: Uses `net-ssh-telnet` for prompt handling
- **Mock mode**: Complete offline development support
- **Enterprise proxy**: Full bastion host and ProxyCommand support
- **Platform detection**: Parses JunOS version from `show version`
- **Error handling**: Device-specific error pattern matching

### URI Patterns

```bash
# Basic connection
juniper://admin@192.168.1.1

# With port and password
juniper://admin:password@device.local:2222

# Enterprise proxy scenario
juniper://admin@internal.device?bastion_host=jump.corp.com&bastion_user=netadmin

# Environment variables
export JUNIPER_HOST=device.local
export JUNIPER_BASTION_HOST=jump.corp.com
inspec detect -t juniper://
```

---

## API-Based Plugin (train-rest)

**Repository**: https://github.com/prospectra/train-rest  
**Pattern**: REST API transport  
**Maintained by**: Thomas Heinen (Prospectra)

### Implementation Approach

```ruby
# Based on train-rest patterns
class Connection < Train::Plugins::Transport::BaseConnection
  def initialize(options)
    @options = options.dup
    @base_url = @options[:host]
    @client = build_rest_client
    super(@options)
  end

  def run_command_via_connection(cmd)
    # Commands map to API endpoints
    endpoint = map_command_to_endpoint(cmd)
    response = @client.get(endpoint)
    
    CommandResult.new(response.body, response.code == 200 ? 0 : 1)
  end

  private

  def build_rest_client
    RestClient::Resource.new(@base_url, {
      user: @options[:user],
      password: @options[:password],
      verify_ssl: @options[:verify_ssl] != false,
      timeout: @options[:timeout] || 30
    })
  end

  def map_command_to_endpoint(cmd)
    case cmd
    when /^show version$/
      '/api/v1/system/version'
    when /^show config$/
      '/api/v1/configuration'
    else
      "/api/v1/exec?command=#{CGI.escape(cmd)}"
    end
  end
end
```

### Unique Characteristics

- **HTTP-based**: Uses RestClient gem for API communication
- **Command mapping**: Translates shell commands to REST endpoints
- **Authentication**: Supports Basic Auth, API keys, OAuth
- **SSL handling**: Configurable certificate verification
- **JSON responses**: Structured data instead of text output

### URI Patterns

```bash
# HTTPS API endpoint
rest://admin:password@api.example.com:443

# With API key authentication
rest://api.example.com?api_key=secret123&verify_ssl=false

# Custom endpoint mapping
rest://admin@localhost:8080/api/v2
```

---

## Cloud Service Plugin (train-awsssm)

**Repository**: https://github.com/prospectra/train-awsssm  
**Pattern**: AWS Systems Manager integration  
**Maintained by**: Thomas Heinen (Prospectra)

### Implementation Approach

```ruby
# Based on train-awsssm patterns
class Connection < Train::Plugins::Transport::BaseConnection
  def initialize(options)
    @options = options.dup
    @instance_id = @options[:host] # EC2 instance ID
    @region = @options[:region] || ENV['AWS_DEFAULT_REGION']
    @ssm_client = build_ssm_client
    super(@options)
  end

  def run_command_via_connection(cmd)
    response = @ssm_client.send_command({
      instance_ids: [@instance_id],
      document_name: "AWS-RunShellScript",
      parameters: { commands: [cmd] },
      timeout_seconds: @options[:timeout] || 3600
    })
    
    wait_for_command_completion(response.command.command_id)
  end

  private

  def build_ssm_client
    require 'aws-sdk-ssm'
    
    Aws::SSM::Client.new(
      region: @region,
      credentials: aws_credentials
    )
  end

  def aws_credentials
    if @options[:access_key_id]
      Aws::Credentials.new(@options[:access_key_id], @options[:secret_access_key])
    else
      # Use IAM role or AWS profile
      nil
    end
  end
end
```

### Unique Characteristics

- **Cloud-native**: No SSH required, uses AWS APIs
- **IAM integration**: Supports AWS credentials and roles
- **Async execution**: Commands run asynchronously via SSM
- **Fleet management**: Can target multiple instances
- **AWS SDK**: Direct integration with AWS services

### URI Patterns

```bash
# Instance ID as hostname
awsssm://i-1234567890abcdef0?region=us-west-2

# With explicit credentials
awsssm://i-1234567890abcdef0?access_key_id=AKIA...&secret_access_key=...

# Using AWS profiles
awsssm://i-1234567890abcdef0?profile=production&region=eu-west-1
```

---

## Container Platform Plugin (train-k8s-container)

**Repository**: https://github.com/inspec/train-k8s-container  
**Pattern**: Kubernetes container execution  
**Maintained by**: InSpec Team

### Implementation Approach

```ruby
# Based on train-k8s-container patterns
class Connection < Train::Plugins::Transport::BaseConnection
  def initialize(options)
    @options = options.dup
    @namespace = @options[:namespace] || 'default'
    @pod_name = @options[:host]
    @container_name = @options[:container]
    @kubectl_client = build_kubectl_client
    super(@options)
  end

  def run_command_via_connection(cmd)
    kubectl_cmd = build_kubectl_exec_command(cmd)
    
    Open3.popen3(kubectl_cmd) do |stdin, stdout, stderr, wait_thr|
      stdin.close
      exit_status = wait_thr.value.exitstatus
      CommandResult.new(stdout.read, exit_status, stderr.read)
    end
  end

  private

  def build_kubectl_exec_command(cmd)
    exec_args = [
      'kubectl', 'exec',
      '-n', @namespace,
      @pod_name
    ]
    
    exec_args += ['-c', @container_name] if @container_name
    exec_args += ['--', 'sh', '-c', cmd]
    
    exec_args.shelljoin
  end
end
```

### Unique Characteristics

- **Kubernetes-native**: Uses kubectl for container access
- **Multi-container**: Supports specific container selection
- **Namespace-aware**: Kubernetes namespace support
- **No direct SSH**: Leverages Kubernetes exec API
- **Context support**: Uses kubectl context and config

### URI Patterns

```bash
# Pod in default namespace
k8s-container://my-pod

# Specific container in pod
k8s-container://my-pod?container=web-server&namespace=production

# With kubectl context
k8s-container://my-pod?context=prod-cluster&namespace=default
```

---

## Windows Automation Plugin (train-pwsh)

**Repository**: https://github.com/mitre/train-pwsh  
**Pattern**: PowerShell-based Windows automation  
**Maintained by**: MITRE SAF Team

### Implementation Approach

```ruby
# Based on train-pwsh patterns (example implementation)
class Connection < Train::Plugins::Transport::BaseConnection
  def initialize(options)
    @options = options.dup
    @shell_type = @options[:shell] || 'powershell'
    @execution_policy = @options[:execution_policy] || 'Bypass'
    super(@options)
  end

  def run_command_via_connection(cmd)
    case @options[:backend]
    when 'winrm'
      run_via_winrm(cmd)
    when 'ssh'
      run_via_ssh(cmd)
    else
      run_locally(cmd)
    end
  end

  private

  def run_via_winrm(cmd)
    # WinRM-based execution for remote Windows hosts
    powershell_cmd = wrap_powershell_command(cmd)
    winrm_session.run(powershell_cmd)
  end

  def run_via_ssh(cmd)
    # SSH-based execution (OpenSSH on Windows)
    ssh_session.exec!(wrap_powershell_command(cmd))
  end

  def wrap_powershell_command(cmd)
    "powershell.exe -ExecutionPolicy #{@execution_policy} -Command \"#{escape_powershell(cmd)}\""
  end
end
```

### Unique Characteristics

- **Multi-protocol**: Supports WinRM, SSH, and local execution
- **PowerShell-centric**: Native Windows command execution
- **Execution policy**: Configurable PowerShell security settings
- **Windows-specific**: Handles Windows paths, encoding, authentication
- **Cross-platform client**: Can run from Linux/macOS to manage Windows

### URI Patterns

```bash
# WinRM connection
pwsh://admin@windows-server:5985?backend=winrm

# SSH to Windows (OpenSSH)
pwsh://admin@windows-server:22?backend=ssh&shell=powershell

# Local execution
pwsh://localhost?backend=local
```

---

## Simple Learning Plugin (train-local-rot13)

**Repository**: https://github.com/inspec/train/tree/master/examples/plugins/train-local-rot13  
**Pattern**: Educational example  
**Maintained by**: InSpec Team

### Complete Implementation

```ruby
# lib/train-local-rot13/transport.rb
class Transport < Train.plugin(1)
  name 'local-rot13'

  def connection(options = nil)
    @connection ||= Connection.new(@options.merge(options || {}))
  end
end

# lib/train-local-rot13/connection.rb
class Connection < Train::Plugins::Transport::BaseConnection
  def run_command_via_connection(cmd)
    # Apply ROT13 transformation to command
    rot13_cmd = cmd.tr('A-Za-z', 'N-ZA-Mn-za-m')
    
    # Execute locally with transformation
    result = `#{rot13_cmd} 2>&1`
    exit_status = $?.exitstatus
    
    CommandResult.new(result, exit_status)
  end
  
  def file_via_connection(path)
    # ROT13 file content transformation
    if File.exist?(path)
      content = File.read(path).tr('A-Za-z', 'N-ZA-Mn-za-m')
      MockFile.new(path, content)
    else
      MockFile.new(path, nil, exists: false)
    end
  end
end
```

### Unique Characteristics

- **Educational focus**: Demonstrates core plugin concepts
- **Local execution**: No network connectivity required
- **Data transformation**: Shows how to modify command/file operations
- **Minimal dependencies**: Uses only Ruby standard library
- **Complete example**: All four required files implemented

### URI Patterns

```bash
# Simple local usage
local-rot13://

# With options (though not used in this implementation)
local-rot13://localhost?option=value
```

---

## Plugin Comparison Matrix

| Plugin | Transport | Authentication | Platform | Primary Use Case |
|--------|-----------|----------------|----------|------------------|
| **train-juniper** | SSH + Telnet | Password, SSH keys, Proxy | Network devices | Infrastructure compliance |
| **train-rest** | HTTP/HTTPS | Basic Auth, API keys | API endpoints | Cloud services, REST APIs |
| **train-awsssm** | AWS SSM | IAM roles, Access keys | EC2 instances | Cloud infrastructure |
| **train-k8s-container** | kubectl exec | Kubernetes auth | Container platforms | Containerized workloads |
| **train-pwsh** | WinRM/SSH/Local | Windows auth | Windows systems | Windows automation |
| **train-local-rot13** | Local execution | None | Local system | Learning/education |

## Architecture Patterns

### 1. Direct Protocol Plugins
```ruby
# SSH, WinRM, HTTP - direct protocol implementation
class Connection < Train::Plugins::Transport::BaseConnection
  def run_command_via_connection(cmd)
    protocol_client.execute(cmd)
  end
end
```

**Examples**: train-juniper (SSH), train-rest (HTTP)

### 2. CLI Wrapper Plugins
```ruby
# Wrap existing CLI tools
class Connection < Train::Plugins::Transport::BaseConnection
  def run_command_via_connection(cmd)
    wrapped_cmd = "#{cli_tool} #{connection_args} -- #{cmd}"
    `#{wrapped_cmd}`
  end
end
```

**Examples**: train-k8s-container (kubectl), train-pwsh (powershell.exe)

### 3. Cloud SDK Plugins
```ruby
# Use cloud provider SDKs
class Connection < Train::Plugins::Transport::BaseConnection
  def run_command_via_connection(cmd)
    cloud_client.send_command(target_resource, cmd)
  end
end
```

**Examples**: train-awsssm (AWS SDK), train-azure (Azure SDK)

### 4. Local Transform Plugins
```ruby
# Modify local execution behavior
class Connection < Train::Plugins::Transport::BaseConnection
  def run_command_via_connection(cmd)
    transformed_cmd = apply_transformation(cmd)
    `#{transformed_cmd}`
  end
end
```

**Examples**: train-local-rot13 (text transformation)

---

## Common Implementation Patterns

### Error Handling Strategy

```ruby
def run_command_via_connection(cmd)
  begin
    execute_command(cmd)
  rescue SpecificProtocolError => e
    CommandResult.new('', 1, "Protocol error: #{e.message}")
  rescue Timeout::Error => e
    CommandResult.new('', 124, "Command timed out: #{cmd}")
  rescue => e
    CommandResult.new('', 255, "Unexpected error: #{e.message}")
  end
end
```

### Connection Lifecycle

```ruby
def initialize(options)
  @options = options.dup
  validate_options
  super(@options)
end

def connect
  @connection ||= establish_connection
end

def close
  @connection&.close
  @connection = nil
end
```

### Platform Detection

```ruby
def platform
  # Force platform for dedicated plugins
  force_platform!(platform_name, platform_details)
end

def platform_details
  {
    release: detect_version,
    arch: determine_architecture,
    family: platform_family
  }
end
```

---

## Key Takeaways

1. **Choose appropriate patterns** - Protocol, CLI wrapper, SDK, or local transform
2. **Follow community standards** - Consistent naming, structure, and behavior
3. **Handle errors gracefully** - Provide meaningful error messages
4. **Support enterprise features** - Proxy, authentication, timeouts
5. **Enable testing** - Mock modes and comprehensive test coverage
6. **Document thoroughly** - Clear usage examples and configuration
7. **Consider maintenance** - Long-term support and updates

**Next**: Learn about [Community Plugins](13-community-plugins.md) and the broader Train ecosystem.
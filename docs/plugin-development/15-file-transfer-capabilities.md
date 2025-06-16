# File Transfer Capabilities

Understanding when and how to implement upload/download file transfer in Train plugins based on transport category patterns.

## Table of Contents

1. [Purpose of File Transfer in Train](#purpose-of-file-transfer-in-train)
2. [Transport Category Patterns](#transport-category-patterns)
3. [InSpec Resource Integration](#inspec-resource-integration)
4. [Implementation Examples](#implementation-examples)
5. [Security Considerations](#security-considerations)
6. [Network Device Considerations](#network-device-considerations)
7. [Decision Matrix](#decision-matrix)

---

## Purpose of File Transfer in Train

### Core Function

Train's file transfer capabilities serve as the **transport abstraction layer** for InSpec compliance testing, enabling secure file operations across diverse infrastructure types while maintaining a consistent API.

### Primary Use Cases

**Essential for Compliance Testing:**
- **Configuration File Access**: Reading `/etc/ssh/sshd_config`, `/etc/passwd`, system configurations
- **Certificate Validation**: Downloading SSL/TLS certificates for expiration and validity checks
- **Log Analysis**: Accessing application and system logs for security compliance
- **Security Policy Verification**: Reading security configuration files and policies
- **Evidence Collection**: Downloading artifacts for compliance documentation

**InSpec Resource Examples:**
```ruby
# These InSpec resources rely on Train's file transfer capabilities
describe file('/etc/ssh/sshd_config') do
  its('content') { should match /PermitRootLogin no/ }
end

describe x509_certificate('/etc/ssl/certs/server.crt') do
  its('validity_in_days') { should be >= 30 }
end

describe json('/etc/docker/daemon.json') do
  its(['log-driver']) { should eq 'journald' }
end
```

### How It Works

```ruby
# InSpec resources access files via Train's file abstraction:
# 1. InSpec calls: connection.file('/path/to/file').content
# 2. Train calls: file_via_connection('/path/to/file')  
# 3. Plugin implements file access appropriate for transport type
```

---

## Transport Category Patterns

### 1. Operating System Transports (IMPLEMENT File Transfer)

**Categories**: SSH, Local, WinRM, Docker/Podman containers

**Why**: These systems have traditional filesystems with files that need compliance checking.

**Implementation Pattern**:
```ruby
def upload(locals, remote)
  Array(locals).each do |local|
    # Actual file transfer using SCP, local copy, etc.
    session.scp.upload(local, remote)
  end
rescue Net::SSH::Exception => ex
  raise Train::Transports::SSHFailed, "Upload failed: #{ex.message}"
end

def download(remotes, local)
  Array(remotes).each do |remote|
    # Actual file download
    session.scp.download(remote, File.join(local, File.basename(remote)))
  end
end
```

**Real Examples**:
- **train-ssh**: Uses `net-scp` for SCP-based transfers with parallel session support
- **train-local**: Uses Ruby's `FileUtils.cp_r` for local file operations
- **train-winrm**: Uses WinRM file APIs for Windows systems

### 2. Network Device Transports (DO NOT IMPLEMENT)

**Categories**: Network switches, routers, firewalls (Cisco IOS, Juniper, F5, etc.)

**Why**: Network devices don't have traditional filesystems - all configuration data is accessed via CLI commands.

**Implementation Pattern**:
```ruby
def upload(locals, remote)
  raise NotImplementedError, "#{self.class} does not implement #upload() - network devices use command-based configuration"
end

def download(remotes, local)  
  raise NotImplementedError, "#{self.class} does not implement #download() - use run_command() to retrieve configuration data"
end
```

**Real Example from train-cisco-ios**:
```ruby
# /lib/train/transports/cisco_ios_connection.rb lines 42-48
def upload(locals, remote)
  raise NotImplementedError, "#{self.class} does not implement #upload()"
end

def download(remotes, local)
  raise NotImplementedError, "#{self.class} does not implement #download()"
end
```

### 3. Cloud API Transports (DO NOT IMPLEMENT)

**Categories**: AWS, Azure, GCP, VMware vSphere APIs

**Why**: Cloud platforms expose configuration via APIs, not files. Use API calls instead.

**Implementation Pattern**:
```ruby
# These methods are not implemented at all in cloud API transports
# Cloud resources use API calls via client libraries instead
```

**Examples**:
- **train-aws**: No upload/download methods - uses AWS SDK API calls
- **train-azure**: No upload/download methods - uses Azure SDK
- **train-gcp**: No upload/download methods - uses Google Cloud APIs

---

## InSpec Resource Integration

### How Resources Use File Transfer

**Standard Pattern**:
```ruby
# InSpec resource calls Train's file abstraction
describe file('/etc/passwd') do
  its('content') { should_not be_empty }
end

# Behind the scenes:
# 1. InSpec calls connection.file('/etc/passwd')
# 2. Train calls your plugin's file_via_connection method
# 3. Your plugin returns a file object with .content method
# 4. File object may use upload/download for content access
```

**File Content Access Patterns**:
```ruby
# For OS-based plugins - file content accessed via download:
def file_via_connection(path)
  # May internally use download() to get file content
  RemoteFile.new(self, path)
end

# For network device plugins - file content from commands:
def file_via_connection(path)
  case path
  when %r{^/config/(.*)}, %r{^/operational/(.*)}
    # Map pseudo-file paths to CLI commands
    JuniperFile.new(self, path)
  end
end
```

### InSpec Resources That Require File Transfer

**Core Resources**:
- `file` - Basic file content and metadata
- `directory` - Directory properties and contents
- `x509_certificate` - Certificate validation
- `json`, `yaml`, `ini` - Configuration file parsing
- `systemd_service` - Service unit file analysis

**Security-Focused Resources**:
- `ssh_config` - SSH daemon configuration
- `ssl` - SSL/TLS certificate validation  
- `etc_hosts` - Host file verification
- `kernel_parameter` - Kernel configuration files

---

## Implementation Examples

### SSH Transport (Full Implementation)

From `/lib/train/transports/ssh_connection.rb`:

```ruby
def upload(locals, remote)
  @logger.debug("Uploading #{locals} to #{remote}")
  
  Array(locals).each do |local|
    # Use net-scp for secure file transfer
    session.scp.upload(local, remote) do |ch, name, sent, total|
      @logger.debug("Uploaded #{name} (#{sent}/#{total} bytes)")
    end
  end
rescue Net::SSH::Exception => ex
  raise Train::Transports::SSHFailed, "SCP upload failed: #{ex.message}"
end

def download(remotes, local)
  @logger.debug("Downloading #{remotes} to #{local}")
  
  Array(remotes).each do |remote|
    local_file = File.join(local, File.basename(remote))
    session.scp.download(remote, local_file) do |ch, name, sent, total|
      @logger.debug("Downloaded #{name} (#{sent}/#{total} bytes)")
    end
  end
rescue Net::SSH::Exception => ex
  raise Train::Transports::SSHFailed, "SCP download failed: #{ex.message}"
end
```

### Local Transport (Direct File Operations)

From `/lib/train/transports/local.rb`:

```ruby
def upload(locals, remote)
  Array(locals).each do |local|
    # Direct file copy for local transport
    FileUtils.cp_r(local, remote, preserve: true)
  end
end

def download(remotes, local)
  Array(remotes).each do |remote|
    # Direct file copy for local transport
    dest = File.join(local, File.basename(remote))
    FileUtils.cp_r(remote, dest, preserve: true)
  end
end
```

### Network Device Pattern (train-cisco-ios)

From `/lib/train/transports/cisco_ios_connection.rb`:

```ruby
def upload(locals, remote)
  raise NotImplementedError, "#{self.class} does not implement #upload()"
end

def download(remotes, local)
  raise NotImplementedError, "#{self.class} does not implement #download()"
end

# Alternative: Command-based data access
def run_command_via_connection(cmd)
  # Network devices expose all data via CLI commands
  execute_command(cmd)
end

def file_via_connection(path)
  # Map file paths to CLI commands
  case path
  when %r{^/running-config}
    # show running-config instead of file access
    CiscoFile.new(self, path)
  end
end
```

### Network Device File Abstraction

```ruby
# Example implementation for network device "files"
class NetworkDeviceFile
  def initialize(connection, path)
    @connection = connection
    @path = path
  end
  
  def content
    # Map pseudo-file paths to CLI commands
    case @path
    when %r{^/config/(.*)}
      # Configuration data: show configuration interfaces
      section = $1
      result = @connection.run_command("show configuration #{section}")
      result.stdout
    when %r{^/operational/(.*)}
      # Operational data: show interfaces
      section = $1
      result = @connection.run_command("show #{section}")
      result.stdout
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

## Security Considerations

### Built-in Security Features

**Audit Logging**:
```ruby
# Train automatically logs all file operations
@audit_log.info({
  type: "file upload",
  source: local,
  destination: remote_file,
  user: @audit_log_data[:username],
  hostname: @audit_log_data[:hostname]
}) if @audit_log
```

**Transport Security**:
- **SSH**: All file transfers use SCP (encrypted and authenticated)
- **Local**: File operations respect local system permissions
- **No Privilege Escalation**: File transfer doesn't bypass system security

### Best Practices

1. **Minimal File Access**: Only read files necessary for compliance validation
2. **Audit Trail**: Enable audit logging for compliance documentation  
3. **Secure Transports**: Use SSH/TLS for all remote file operations
4. **File Validation**: Verify file integrity and authenticity
5. **Temporary Storage**: Clean up downloaded files after analysis

### Error Handling

```ruby
def secure_download(remotes, local)
  begin
    download(remotes, local)
  rescue Train::TransportError => e
    @logger.error("Secure download failed: #{e.message}")
    # Clean up any partial downloads
    cleanup_failed_downloads(local)
    raise
  end
end
```

---

## Network Device Considerations

### Why Network Devices Don't Need File Transfer

1. **No Traditional Filesystem**: Network devices store configuration in databases, not files
2. **Command-Based Access**: All data accessible via CLI commands (`show running-config`)
3. **Structured Output**: Modern devices support JSON/XML output for parsing
4. **API Consistency**: Follows same pattern as cloud API transports

### Alternative Patterns for Network Devices

**JSON Output Approach**:
```ruby
def get_interfaces_config
  result = run_command("show configuration interfaces | display json")
  JSON.parse(result.stdout)
end

# InSpec resource usage:
describe json(command: 'show configuration interfaces | display json') do
  its(['interface', 'ge-0/0/0', 'description']) { should eq 'WAN Interface' }
end
```

**Pseudo-File Mapping**:
```ruby
# Map file-like paths to commands for InSpec compatibility
def file_via_connection(path)
  case path
  when '/config/interfaces'
    result = run_command('show configuration interfaces')
    MockFile.new(result.stdout)
  when '/status/interfaces'  
    result = run_command('show interfaces terse')
    MockFile.new(result.stdout)
  end
end

# Enables InSpec usage like:
describe file('/config/interfaces') do
  its('content') { should match /ge-0\/0\/0/ }
end
```

---

## Decision Matrix

Use this matrix to determine if your plugin should implement file transfer:

| Transport Category | Implement Upload/Download? | Rationale | Examples |
|-------------------|---------------------------|-----------|-----------|
| **Operating Systems** | ✅ **YES** | Traditional filesystems with config files | SSH, Local, WinRM |
| **Containers** | ✅ **YES** | Container filesystems accessible via APIs | Docker, Podman, Kubernetes |
| **Network Devices** | ❌ **NO** | Command-based configuration, no filesystem | Cisco IOS, Juniper, F5 |
| **Cloud APIs** | ❌ **NO** | Configuration via API calls, not files | AWS, Azure, GCP |
| **Database Systems** | ❌ **NO** | Configuration via SQL/API, not files | MySQL, PostgreSQL |
| **Application APIs** | ❌ **NO** | Configuration via HTTP/REST APIs | REST services, GraphQL |

### Implementation Guide

**If YES (Implement File Transfer)**:
1. Use `net-scp` for SSH-based transports
2. Use transport-appropriate APIs (WinRM, Docker API)
3. Implement proper error handling and logging
4. Support both upload and download operations
5. Handle file permissions and security properly

**If NO (Do Not Implement)**:
1. Raise `NotImplementedError` with helpful message
2. Implement command-based or API-based data access
3. Create pseudo-file abstraction if needed for InSpec compatibility
4. Document alternative data access patterns

### Code Template

**For transports that should NOT implement file transfer**:
```ruby
def upload(locals, remote)
  raise NotImplementedError, 
    "#{self.class} does not implement #upload() - " \
    "#{transport_type} uses #{data_access_method} for configuration access"
end

def download(remotes, local)
  raise NotImplementedError,
    "#{self.class} does not implement #download() - " \
    "use #{alternative_method} to retrieve configuration data"
end

# Examples:
# "network devices use command-based configuration access"
# "cloud APIs use SDK calls for configuration retrieval"  
# "use run_command() to retrieve configuration data"
```

---

## Key Takeaways

1. **File transfer is transport-category dependent** - not all plugins need it
2. **Operating system transports implement file transfer** for compliance file access
3. **Network device and API transports do NOT implement file transfer** - use commands/APIs instead
4. **InSpec resources rely on file abstraction** - may need pseudo-file mapping for network devices
5. **Security and audit logging are built-in** for compliant file operations
6. **Follow existing patterns** - Cisco IOS plugin shows the network device approach

Understanding these patterns ensures your plugin integrates properly with the Train ecosystem and provides the right data access methods for your target infrastructure type.

---

**Next**: Learn about [Error Handling Patterns](16-error-handling-patterns.md) for robust plugin development.
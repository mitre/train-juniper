# Train Plugin Basics

Understanding Train's role in the InSpec ecosystem and why plugins matter for compliance automation.

## Table of Contents

1. [What is Train?](#what-is-train)
2. [Train's Role in InSpec](#trains-role-in-inspec)
3. [Why Write a Train Plugin?](#why-write-a-train-plugin)
4. [Core Concepts](#core-concepts)
5. [The Train Plugin Ecosystem](#the-train-plugin-ecosystem)
6. [Plugin Types and Examples](#plugin-types-and-examples)
7. [Getting Started Checklist](#getting-started-checklist)

---

## What is Train?

**Train** is the connectivity layer that sits between InSpec (the compliance testing tool) and target systems. Think of it as the "driver" that enables InSpec to talk to different types of systems through a consistent interface.

### The Problem Train Solves

InSpec needs to connect to many different types of systems:
- Linux and Windows servers via SSH/WinRM
- Network devices via SSH/Telnet/NETCONF
- Cloud APIs (AWS, Azure, Google Cloud)
- Container platforms (Docker, Kubernetes)
- Databases and message queues
- Custom applications and IoT devices

Without Train, InSpec would need to implement dozens of different connection methods. Train abstracts this complexity behind a single, consistent API.

### How Train Works

```
InSpec Test → Train Plugin → Target System
     ↓              ↓             ↓
"Check SSH"  → SSH Connection → Linux Server
"Check API"  → REST Transport → Cloud API
"Check DB"   → DB Connection  → Database
```

**InSpec writes tests using Train's API:**
```ruby
# InSpec test code - same for all systems
describe command('ls /etc') do
  its('stdout') { should match /passwd/ }
end

describe file('/etc/passwd') do
  it { should exist }
end
```

**Train handles the connectivity details:**
- SSH connections and authentication
- API calls and token management  
- File system abstraction
- Platform detection and capabilities

---

## Train's Role in InSpec

### InSpec's Architecture

```
┌─────────────────┐
│  InSpec Tests   │  ← User writes compliance tests
├─────────────────┤
│ InSpec Resources│  ← file, command, service, etc.
├─────────────────┤
│   Train API     │  ← Consistent connection interface
├─────────────────┤
│ Train Plugins   │  ← Transport implementations
├─────────────────┤
│ Target Systems  │  ← Servers, APIs, devices, etc.
└─────────────────┘
```

### Key Integration Points

1. **Connection Management**: Train establishes and maintains connections
2. **Command Execution**: InSpec `command()` resource uses Train's `run_command()`
3. **File Operations**: InSpec `file()` resource uses Train's file abstraction
4. **Platform Detection**: Train identifies the target system type
5. **Authentication**: Train handles credentials and authentication methods

### Example: InSpec Test Flow

```ruby
# User runs: inspec exec profile -t juniper://admin@switch.corp.com

# 1. Train parses the target URI
config = Train.target_config(target: "juniper://admin@switch.corp.com")
# => { backend: "juniper", host: "switch.corp.com", user: "admin" }

# 2. Train creates the transport
transport = Train.create("juniper", config)

# 3. Train establishes connection
connection = transport.connection

# 4. InSpec uses Train's API for tests
result = connection.run_command("show version")
file_content = connection.file("/config/interfaces").content
platform = connection.os
```

---

## Why Write a Train Plugin?

### Enable InSpec for New Platforms

Train plugins extend InSpec's reach to new types of systems:

- **Network Devices**: Juniper, Cisco, Arista, Palo Alto firewalls
- **IoT Platforms**: Industrial controllers, smart devices, embedded systems  
- **Custom APIs**: Internal applications, microservices, proprietary systems
- **Specialized Protocols**: Serial, Modbus, SNMP, custom TCP protocols
- **Cloud Services**: Custom cloud providers, managed services

### Standardize Access Patterns

Instead of each team building custom compliance scripts, Train plugins provide:

- **Consistent Interface**: Same InSpec tests work across different systems
- **Shared Authentication**: Standard credential management and proxy support
- **Common File Abstraction**: Access configuration and logs through familiar patterns
- **Platform Detection**: Automatic identification of system types and versions

### Leverage InSpec's Ecosystem

Train plugins inherit InSpec's powerful features:

- **Rich Testing DSL**: Descriptive test syntax with built-in matchers
- **Compliance Profiles**: Reusable test suites (CIS, STIG, custom frameworks)
- **Reporting Integration**: JSON, CLI, JUnit, and custom report formats
- **CI/CD Integration**: Automated compliance testing in deployment pipelines

---

## Core Concepts

### Plugin vs Transport vs Connection

Understanding the terminology is crucial:

- **Plugin**: The entire Ruby gem package (e.g., `train-juniper`)
- **Transport**: The connectivity implementation class within the plugin
- **Connection**: An active session instance to a specific target
- **Platform**: The target system identification and capabilities

```ruby
# Plugin: train-juniper gem
# Transport: TrainPlugins::Juniper::Transport class
# Connection: Active SSH session to switch.corp.com
# Platform: { name: "juniper", release: "21.4R3", family: "network" }
```

### The Four-File Plugin Structure

Every Train plugin follows the same structure:

```
lib/train-yourname/
├── version.rb       # Plugin version constant
├── transport.rb     # Plugin registration and options
├── connection.rb    # Core connection implementation
└── platform.rb     # Platform detection logic
```

**Entry Point** (`lib/train-yourname.rb`):
```ruby
require "train-yourname/version"
require "train-yourname/transport" 
require "train-yourname/connection"
require "train-yourname/platform"
```

### Plugin Registration

Train discovers plugins through naming convention:

1. **Gem Name**: Must be prefixed with `train-` (e.g., `train-juniper`)
2. **Plugin Registration**: Registers as short name (e.g., `juniper`)  
3. **Class Namespace**: `TrainPlugins::YourName::*`

```ruby
# Users specify: inspec -t juniper://...
# Train looks for: train-juniper gem
# Train loads: TrainPlugins::Juniper::Transport
```

### Train Plugin API

Only **Train Plugin API v1** exists (despite documentation suggesting v2):

```ruby
# CORRECT - Only version available
class Transport < Train.plugin(1)
  name "yourname"
  
  option :host, required: true
  option :user, required: true
  
  def connection(_instance_opts = nil)
    @connection ||= TrainPlugins::YourName::Connection.new(@options)
  end
end

# WRONG - Version 2 doesn't exist
class Transport < Train.plugin(2)  # Will fail!
```

---

## The Train Plugin Ecosystem

### Official Train Transports

**Built into Train core:**
- `ssh` - SSH connections to Unix/Linux systems
- `winrm` - Windows Remote Management
- `local` - Local system execution
- `docker` - Docker container connections
- `podman` - Podman container connections

### Community Plugins

**Network Infrastructure:**
- `train-juniper` - Juniper Networks JunOS devices (this project)
- `train-cisco-ios` - Cisco IOS network devices
- `train-arista-eos` - Arista EOS switches

**Cloud and APIs:**
- `train-rest` - REST API connections with multiple auth methods
- `train-awsssm` - AWS Systems Manager connections
- `train-azure` - Azure resource management
- `train-gcp` - Google Cloud Platform resources

**Specialized Systems:**
- `train-k8s-container` - Kubernetes pod containers
- `train-vsphere` - VMware vSphere virtual machines
- `train-telnet` - Telnet connections for legacy systems

### Plugin Quality Levels

**Production Ready:**
- Comprehensive test coverage
- Enterprise authentication support
- Clear documentation and examples
- Active maintenance and community

**Experimental:**
- Basic functionality working
- Limited testing or documentation
- May have breaking changes
- Suitable for development environments

**Community Examples:**
- Learning and reference implementations
- May lack enterprise features
- Good starting points for new plugins

---

## Plugin Types and Examples

### 1. Network Device Plugins

**Use Case**: Infrastructure compliance for routers, switches, firewalls

**Example**: train-juniper
```bash
# Connect to Juniper device
inspec detect -t "juniper://admin@firewall.corp?bastion_host=jump.corp"

# Test configuration
describe command('show configuration security') do
  its('stdout') { should match /security-zone/ }
end
```

**Key Features:**
- SSH connectivity with prompt handling
- Network device command execution
- Configuration file access via pseudo-files
- Support for enterprise jump hosts/proxies

### 2. API-Based Plugins

**Use Case**: Cloud services, web applications, microservices compliance

**Example**: train-rest
```bash
# Connect to REST API
inspec exec profile -t "rest://api.company.com/v1/?auth_type=bearer&token=xyz"

# Test API responses
describe http_get('/health') do
  its('status') { should eq 200 }
  its('body') { should match /healthy/ }
end
```

**Key Features:**
- Multiple authentication methods (Bearer, API keys, OAuth)
- HTTP verb mapping to commands
- JSON/XML response parsing
- SSL/TLS configuration

### 3. Cloud Resource Plugins

**Use Case**: Infrastructure as Code compliance, cloud governance

**Example**: train-awsssm
```bash
# Connect via AWS Systems Manager
inspec detect -t "awsssm://i-1234567890abcdef0"

# Test EC2 instance configuration
describe command('cat /etc/ssh/sshd_config') do
  its('stdout') { should match /PermitRootLogin no/ }
end
```

**Key Features:**
- Cloud SDK integration
- IAM role-based authentication
- Resource lifecycle management
- Multi-region support

### 4. Container Platform Plugins

**Use Case**: Container security, Kubernetes compliance

**Example**: train-k8s-container
```bash
# Connect to Kubernetes pod
inspec exec profile -t "k8s-container://prod/web-app/nginx"

# Test container configuration
describe file('/etc/nginx/nginx.conf') do
  its('content') { should match /worker_processes/ }
end
```

**Key Features:**
- Kubernetes namespace support
- Multi-container pod access
- Ephemeral connection handling
- RBAC integration

---

## Getting Started Checklist

Before building your Train plugin:

### 1. Understand Your Target System

- [ ] **Connection Method**: SSH, HTTP, WebSocket, custom protocol?
- [ ] **Authentication**: Username/password, API keys, certificates, cloud IAM?
- [ ] **Command Interface**: CLI commands, API endpoints, database queries?
- [ ] **File Access**: File system, configuration APIs, object storage?
- [ ] **Platform Detection**: How to identify system type and version?

### 2. Choose Your Plugin Pattern

- [ ] **SSH-style**: For network devices and traditional infrastructure
- [ ] **API-style**: For web services and HTTP-based systems
- [ ] **Cloud-style**: For cloud resources and managed services
- [ ] **Container-style**: For containerized workloads
- [ ] **Protocol-style**: For specialized hardware or protocols

See [URI Design Patterns](04-uri-design-patterns.md) for detailed guidance.

### 3. Plan Your Implementation

- [ ] **Plugin Name**: Choose unique name (check RubyGems)
- [ ] **Connection Options**: What parameters do users need to provide?
- [ ] **Authentication Strategy**: How will credentials be managed?
- [ ] **Enterprise Features**: Proxy support, environment variables, config files?
- [ ] **Testing Approach**: Mock mode, real device testing, CI/CD integration?

### 4. Set Up Development Environment

- [ ] **Ruby 3.0+**: Modern Ruby development environment
- [ ] **Bundler**: Dependency management
- [ ] **Git**: Version control
- [ ] **Test Framework**: MiniTest for consistency with Train core
- [ ] **Target System Access**: Real or simulated environment for testing

### 5. Study Existing Plugins

Before implementing, study plugins similar to your use case:

- **Network devices**: `train-juniper`, existing SSH transports
- **APIs**: `train-rest`, cloud provider plugins  
- **Containers**: `train-k8s-container`, Docker transport
- **Specialized**: `train-vsphere`, `train-awsssm`

---

## What's Next?

Now that you understand Train's role and plugin fundamentals:

1. **[Development Setup](02-development-setup.md)** - Set up your plugin project
2. **[Plugin Architecture](03-plugin-architecture.md)** - Implement the 4-file structure
3. **[URI Design Patterns](04-uri-design-patterns.md)** - Choose your connection URI style
4. **[Connection Implementation](05-connection-implementation.md)** - Build your core connectivity

---

## Key Takeaways

- **Train abstracts connectivity** - InSpec tests are the same regardless of target system
- **Plugins extend InSpec's reach** - Enable compliance testing for any connected system
- **Follow established patterns** - SSH, API, Cloud, Container, and Protocol styles serve different audiences
- **Think enterprise-ready** - Support authentication, proxies, and automation from day one
- **Start with existing examples** - Study similar plugins before implementing your own

**Next**: Set up your development environment with [Development Setup](02-development-setup.md).
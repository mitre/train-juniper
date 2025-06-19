# Train Juniper Plugin

A production-ready Train plugin that provides SSH connectivity to Juniper Networks devices running JunOS for InSpec compliance testing and infrastructure inspection.

!!! info "Quick Start"
    Install the plugin: `inspec plugin install train-juniper` and start testing your Juniper infrastructure immediately.

## Features :material-star:

The plugin supports:

- :material-ssh: **SSH Authentication** - Secure connections with password or key-based auth
- :material-router-network: **JunOS Platform Detection** - Automatic version parsing and platform registration  
- :material-console: **Command Execution** - CLI command execution with Juniper-specific prompt handling
- :material-network: **Proxy/Bastion Support** - Enterprise network connectivity through jump hosts
- :material-file-document: **Configuration Inspection** - Pseudo-file operations for configuration access
- :material-test-tube: **Mock Mode** - Complete testing support without requiring real hardware
- :material-speedometer: **Performance Optimized** - Efficient platform detection with result caching

## Installation :material-download:

!!! warning "Prerequisites"
    You will need InSpec v4.0 or later.

### Production Installation (from RubyGems)

```bash
# Search for train plugins
$ inspec plugin search train-

# Install train-juniper (once published)
$ inspec plugin install train-juniper

# Verify installation
$ inspec plugin list
```

### Development Installation (local testing)

```bash
# Clone the repository
$ git clone https://github.com/mitre/train-juniper.git
$ cd train-juniper

# Install dependencies and run tests
$ bundle install
$ bundle exec rake test

# Build and install local gem
$ gem build train-juniper.gemspec
$ inspec plugin install ./train-juniper-0.1.0.gem

# Verify plugin is loaded
$ inspec plugin list
```

## Usage

### Basic Connection

```bash
# Detect platform
$ inspec detect -t juniper://admin@192.168.1.1 --password yourpassword

== Platform Details
Name:      juniper
Families:  network
Release:   21.4R3-S1.6
Arch:      network

# Interactive shell
$ inspec shell -t juniper://admin@192.168.1.1 --password yourpassword
inspec> command('show version').stdout
=> "Hostname: srx-fw\nModel: SRX340\nJunos: 21.4R3-S1.6\n..."
```

### With Bastion Host (Jump Host)

```bash
# Using Train standard bastion host options
$ inspec shell -t "juniper://admin@10.1.1.1?bastion_host=jump.example.com&bastion_user=netadmin&bastion_password=jumppass"

# With custom port
$ inspec shell -t "juniper://admin@10.1.1.1?bastion_host=jump.example.com&bastion_user=netadmin&bastion_port=2222&bastion_password=jumppass"

# Using environment variables (recommended for automation)
export JUNIPER_BASTION_HOST=jump.example.com
export JUNIPER_BASTION_USER=netadmin  
export JUNIPER_BASTION_PASSWORD=jump_password
export JUNIPER_PASSWORD=device_password
$ inspec shell -t juniper://admin@10.1.1.1

# Same password for both bastion and device (common scenario)
export JUNIPER_BASTION_HOST=jump.example.com
export JUNIPER_BASTION_USER=admin
export JUNIPER_PASSWORD=shared_password  # Used for both when bastion_password not set
$ inspec shell -t juniper://admin@10.1.1.1
```

### With Custom Proxy Command

```bash
# Using SSH ProxyCommand syntax  
$ inspec shell -t "juniper://admin@device.internal?proxy_command=ssh%20jump.host%20-W%20%h:%p"

# Complex corporate network scenario
$ inspec detect -t "juniper://netadmin@core-switch.corp?bastion_host=jump.dmz.corp&bastion_user=svc_inspec"
```

### Environment Variables (Auto-Detection)

The plugin automatically detects and uses standard environment variables, eliminating the need to pass connection flags:

```bash
# Basic connection with auto-detection
export JUNIPER_HOST=192.168.1.1
export JUNIPER_USER=admin  
export JUNIPER_PASSWORD=yourpassword
inspec detect -t juniper://  # No flags needed!

# With bastion host auto-detection
export JUNIPER_HOST=internal.device.corp
export JUNIPER_USER=netadmin
export JUNIPER_PASSWORD=devicepass
export JUNIPER_BASTION_HOST=jump.corp.com
export JUNIPER_BASTION_USER=admin
export JUNIPER_BASTION_PASSWORD=bastionpass
inspec detect -t juniper://  # Automatically uses bastion!

# Using .env file (recommended for development)
# Create .env file with your credentials:
source .env
inspec detect -t juniper://  # Reads from .env automatically
```

## Configuration Options

### Connection Options

| Option | Description | Default | Environment Variable |
|--------|-------------|---------|---------------------|
| `host` | Juniper device hostname/IP | - | `JUNIPER_HOST` |
| `user` | SSH username | - | `JUNIPER_USER` |
| `password` | SSH password | - | `JUNIPER_PASSWORD` |
| `port` | SSH port | 22 | `JUNIPER_PORT` |
| `timeout` | Connection timeout (seconds) | 30 | `JUNIPER_TIMEOUT` |
| `keepalive` | SSH keepalive enabled | true | - |
| `keepalive_interval` | SSH keepalive interval (seconds) | 60 | - |

### Proxy/Bastion Options

| Option | Description | Default | Environment Variable |
|--------|-------------|---------|---------------------|
| `bastion_host` | SSH bastion/jump host | - | `JUNIPER_BASTION_HOST` |
| `bastion_user` | SSH bastion username | root | `JUNIPER_BASTION_USER` |
| `bastion_port` | SSH bastion port | 22 | `JUNIPER_BASTION_PORT` |
| `bastion_password` | Password for bastion authentication | - | `JUNIPER_BASTION_PASSWORD` |
| `proxy_command` | Custom SSH ProxyCommand | - | `JUNIPER_PROXY_COMMAND` |
| `key_files` | SSH private key files | - | - |
| `keys_only` | Use only specified keys | false | - |

**Notes**: 
- Cannot specify both `bastion_host` and `proxy_command` simultaneously
- If `bastion_password` not provided, falls back to using `password` for bastion authentication
- Supports automated password authentication via SSH_ASKPASS mechanism

### InSpec Configuration File

Create `~/.inspec/config.json`:

```json
{
  "credentials": {
    "juniper-lab": {
      "target": "juniper://admin@lab-srx.example.com",
      "password": "yourpassword",
      "insecure": true
    }
  }
}
```

Then use: `inspec detect --config=juniper-lab`

## Proxy Connection Patterns

The train-juniper plugin supports Train-standard proxy/bastion connections for enterprise environments where Juniper devices are behind jump hosts or in isolated network segments.

### Authentication Patterns

**Important**: Train does not have a separate `--bastion-password` option. Here are the standard authentication patterns:

#### 🔐 **Same Credentials (Most Common)**
Use the same `--password` for both bastion host and Juniper device:

```bash
# Same username/password for jump host and device
inspec detect -t "juniper://admin@device.internal?bastion_host=jump.corp.com&bastion_user=admin" --password "shared_password"

# With environment variables
export JUNIPER_PASSWORD="shared_password"
inspec shell -t "juniper://admin@device.internal?bastion_host=jump.corp.com&bastion_user=admin"
```

#### 🔑 **SSH Key Authentication (Recommended)**
Use SSH keys for both connections:

```bash
# SSH keys for both bastion and device
inspec detect -t "juniper://admin@device.internal?bastion_host=jump.corp.com&bastion_user=admin" -i ~/.ssh/id_rsa

# With multiple keys
inspec shell -t "juniper://admin@device.internal?bastion_host=jump.corp.com" --key-files ~/.ssh/bastion_key ~/.ssh/device_key
```

#### 🔗 **Different Credentials (Advanced)**
Use SSH ProxyCommand when bastion and device require different authentication:

```bash
# Bastion uses one password, device uses another (embed bastion auth in proxy command)
inspec detect -t "juniper://deviceuser@device.internal?proxy_command=sshpass%20-p%20bastionpass%20ssh%20bastionuser@jump.corp.com%20-W%20%h:%p" --password "device_password"

# Bastion uses SSH key, device uses password
inspec shell -t "juniper://admin@device.internal?proxy_command=ssh%20-i%20~/.ssh/bastion_key%20admin@jump.corp.com%20-W%20%h:%p" --password "device_password"
```

### Bastion Host Scenarios

```bash
# Corporate network with dedicated jump host
inspec exec profile -t "juniper://admin@core-switch.internal?bastion_host=jump.corp.com&bastion_user=netadmin" --password "shared_password"

# Cloud environment with bastion instance  
inspec exec profile -t "juniper://ubuntu@10.0.1.100?bastion_host=bastion.aws.company.com&bastion_port=2222" --key-files ~/.ssh/aws_key

# DMZ access pattern
inspec detect -t "juniper://operator@firewall.dmz?bastion_host=jump.dmz.corp&bastion_user=svc_account" --password "corporate_password"
```

### Custom Proxy Commands

```bash
# SSH ProxyCommand for complex routing
inspec shell -t "juniper://admin@device?proxy_command=ssh%20-o%20StrictHostKeyChecking=no%20jump%20nc%20%h%20%p"

# Multi-hop proxy (SSH chain)
inspec exec profile -t "juniper://admin@target?proxy_command=ssh%20-J%20first-jump,second-jump%20-W%20%h:%p"
```

### SSH Key Authentication with Proxy

```ruby
# In Ruby code or configuration
Train.create('juniper', {
  host: 'secure.device.corp',
  user: 'admin',
  bastion_host: 'jump.corp.com',
  bastion_user: 'automation',
  key_files: ['/path/to/private/key'],
  keys_only: true
})
```

### Common Authentication Issues

#### ❌ **Error**: "No bastion password specified"
**Solution**: Train doesn't have `--bastion-password`. Use one of these patterns:
```bash
# Same password for both (most common)
inspec detect -t "juniper://user@device?bastion_host=jump" --password "shared_pass"

# SSH keys (recommended)  
inspec detect -t "juniper://user@device?bastion_host=jump" --key-files ~/.ssh/id_rsa

# Different passwords (use proxy command)
inspec detect -t "juniper://user@device?proxy_command=sshpass%20-p%20jumppass%20ssh%20jumpuser@jump%20-W%20%h:%p" --password "device_pass"
```

#### ❌ **Error**: "Authentication failed"
**Solutions**:
```bash
# Verify bastion connection first
ssh jumpuser@jump.corp.com

# Test direct device connection (if accessible)
ssh deviceuser@device.internal

# Use verbose SSH for debugging
inspec detect -t "juniper://user@device?bastion_host=jump&proxy_command=ssh%20-v%20jump%20-W%20%h:%p" --password "pass"

# Use InSpec debug mode for detailed logging
inspec detect -t "juniper://user@device?bastion_host=jump" --password "pass" -l debug
```

#### ❌ **Error**: "Connection timeout"
**Solutions**:
```bash
# Increase timeouts
inspec detect -t "juniper://user@device?bastion_host=jump&connection_timeout=60" --password "pass"

# Check network connectivity
ping device.internal  # From bastion host
telnet device.internal 22  # Test SSH port
```

## Mock Mode (Testing Without Hardware)

The train-juniper plugin includes a comprehensive mock mode for testing profiles without requiring physical Juniper hardware:

```bash
# Use mock mode with InSpec detect
inspec detect -t "juniper://admin@mock-device?mock=true"

# Output shows mocked JunOS platform:
# Name:      juniper
# Families:  bsd
# Release:   12.1X47-D15.4
```

For programmatic usage in tests:
```ruby
require 'train'
connection = Train.create('juniper', 
  host: 'test-device',
  user: 'admin',
  mock: true
)

# Mock mode returns predefined responses
result = connection.run_command('show version')
# => Returns mock JunOS version output
```

Mock mode provides:
- ✅ Realistic JunOS command outputs
- ✅ Platform detection (JunOS 12.1X47-D15.4)
- ✅ Error simulation for negative testing
- ✅ Fast execution for CI/CD pipelines

## Development

### Requirements

- Ruby 3.1+
- Bundler
- InSpec 4.0+ (for testing)

### Setup

```bash
git clone https://github.com/mitre/train-juniper.git
cd train-juniper
bundle install
```

### Testing

```bash
# Run all tests
bundle exec rake test

# Run individual test suites  
bundle exec ruby test/unit/connection_test.rb
bundle exec ruby test/functional/juniper_test.rb

# Lint code
bundle exec rubocop
```

### Architecture

This plugin implements the Train Plugin V1 API with:

- **Transport** (`lib/train-juniper/transport.rb`) - Plugin registration and factory
- **Connection** (`lib/train-juniper/connection.rb`) - SSH connectivity and command execution  
- **Platform** (`lib/train-juniper/platform.rb`) - JunOS platform detection
- **Version** (`lib/train-juniper/version.rb`) - Plugin version management

### Documentation

- **[Installation Guide](installation.md)** - Complete installation instructions
- **[Basic Usage](basic-usage.md)** - Getting started with the plugin
- **[Release Process](RELEASE_PROCESS.md)** - How to cut releases and publish gems
- **[Project Roadmap](ROADMAP.md)** - Future development plans and contribution opportunities

### Plugin Development Resources

- **[Train Plugin Development Guide](https://github.com/mitre/train-plugin-development-guide)** - Comprehensive tutorial for Train plugin development
- **How This Plugin Was Built** - See modules 20-22 in the development guide for our research methodology, implementation approach, and containerlab testing environment

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Run `bundle exec rake test` 
5. Submit a pull request

## Support and Contact

For questions, feature requests, or general support:
- Email: [saf@mitre.org](mailto:saf@mitre.org)
- GitHub Issues: [https://github.com/mitre/train-juniper/issues](https://github.com/mitre/train-juniper/issues)

For security issues or vulnerabilities:
- Email: [saf-security@mitre.org](mailto:saf-security@mitre.org)
- GitHub Security: [https://github.com/mitre/train-juniper/security](https://github.com/mitre/train-juniper/security)

## Acknowledgments

This project was inspired by and references several excellent community Train plugins:

- **[train-rest](https://github.com/prospectra/train-rest)** by Thomas Heinen (Prospectra) - REST API transport patterns
- **[train-awsssm](https://github.com/prospectra/train-awsssm)** by Thomas Heinen (Prospectra) - AWS Systems Manager transport  
- **[train-pwsh](https://github.com/mitre/train-pwsh)** by MITRE SAF Team - PowerShell/Windows automation transport
- **[train-k8s-container](https://github.com/inspec/train-k8s-container)** by InSpec Team - Kubernetes container platform detection
- **[train-local-rot13](https://github.com/inspec/train/tree/master/examples/plugins/train-local-rot13)** by InSpec Team - Official plugin development example

Special thanks to the Train and InSpec communities for their excellent documentation and plugin examples.

## License

Licensed under the Apache-2.0 license, except as noted below.

See [LICENSE](LICENSE.md) for full details.

### Notice

This software was produced for the U.S. Government under contract and is subject to Federal Acquisition Regulation Clause 52.227-14.

See [NOTICE](NOTICE.md) for full details.

© 2025 The MITRE Corporation.

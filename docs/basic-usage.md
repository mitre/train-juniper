# Basic Usage

Learn how to use the Train-Juniper plugin for InSpec compliance testing of Juniper devices.

## Quick Start

!!! tip "First Time Setup"
    Complete these three steps to get started with Train-Juniper

### 1. Install the Plugin :material-download:

```bash
inspec plugin install train-juniper
```

### 2. Test Connection :material-network:

```bash
# Test connection to your device
inspec detect -t juniper://admin@your-juniper-device.com
```

!!! success "Expected Output"
    ```
    You are currently running on:
        Name:      juniper
        Families:  bsd, unix, os  
        Release:   23.4R1.9
        Arch:      amd64
    ```

### 3. Run a Simple Check :material-check:

```bash title="Basic Compliance Check"
# Run basic compliance check
inspec exec -t juniper://admin@your-juniper-device.com -c '
  describe command("show version") do
    its("exit_status") { should eq 0 }
    its("stdout") { should match /Junos:/ }
  end
'
```

## Connection Methods

!!! info "Multiple Ways to Connect"
    Choose the method that best fits your workflow and security requirements

### Environment Variables :material-star: { .annotate }

1. **Recommended for automation and CI/CD**

```bash title="Set Environment Variables"
# Set connection details
export JUNIPER_HOST=your-device.example.com
export JUNIPER_USER=admin
export JUNIPER_PASSWORD=your_password

# Connect using environment variables
inspec detect -t juniper://
```

!!! warning "Security Note"
    Store passwords securely using tools like :material-key: **HashiCorp Vault** or **AWS Secrets Manager** in production.

### Direct Connection

```bash
# Username and password in URL
inspec detect -t juniper://admin:password@device.example.com
```

### SSH Key Authentication

```bash
# Using SSH private key
inspec detect -t juniper://admin@device.example.com --key-files ~/.ssh/id_rsa
```

### Custom SSH Port

```bash
# Non-standard SSH port
inspec detect -t juniper://admin@device.example.com:2222
```

### Through Bastion Host

```bash
# Connect through jump host
inspec detect -t juniper://admin@device.example.com \
  --bastion-host jump.example.com \
  --bastion-user bastion_user
```

## Simple InSpec Examples

### Check Device Information

```ruby
# Basic device connectivity and version check
control 'juniper-connectivity' do
  title 'Device Connectivity'
  desc 'Verify we can connect and get basic device information'
  
  describe command('show version') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match /Junos:/ }
    its('stdout') { should_not be_empty }
  end
  
  describe os do
    its('name') { should eq 'juniper' }
    its('family') { should eq 'bsd' }
  end
end
```

### Check Device Configuration

```ruby
# Verify basic device configuration
control 'juniper-hostname' do
  title 'Device Hostname'
  desc 'Check device hostname is configured'
  
  describe command('show system hostname') do
    its('exit_status') { should eq 0 }
    its('stdout') { should_not be_empty }
  end
end

control 'juniper-interfaces' do
  title 'Interface Status'
  desc 'Check that interfaces are configured'
  
  describe command('show interfaces terse') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match /inet/ }
  end
end
```

### JSON Parsing Example

```ruby
# Use structured JSON output for reliable parsing
control 'juniper-version-json' do
  title 'JunOS Version Check (JSON)'
  desc 'Verify JunOS version using structured JSON output'
  
  describe json(command: 'show version | display json') do
    # Access nested JSON data
    its(['software-information', 0, 'junos-version', 0, 'data']) { should match /\d+\.\d+R\d+/ }
    its(['software-information', 0, 'host-name', 0, 'data']) { should_not be_empty }
  end
end

control 'juniper-interface-json' do
  title 'Interface Configuration (JSON)'
  desc 'Check interface configuration using JSON parsing'
  
  describe json(command: 'show interfaces terse | display json') do
    let(:interfaces) { subject['interface-information'][0]['physical-interface'] }
    
    it 'should have at least one configured interface' do
      expect(interfaces).to_not be_empty
    end
    
    it 'should have management interface' do
      mgmt_interface = interfaces.find { |iface| 
        iface['name'][0]['data'].match?(/fxp0|em0|me0/) 
      }
      expect(mgmt_interface).to_not be_nil
    end
  end
end
```

## Mock Mode Testing :material-test-tube:

!!! abstract "Testing Without Hardware"
    Perfect for development, CI/CD pipelines, and learning InSpec

When you don't have access to a real Juniper device, you can test using mock mode:

=== "Quick Test"
    ```bash
    # Test with mock mode (no real device needed)  
    inspec detect -t juniper://mock
    ```

=== "Profile Testing"
    ```bash
    # Run profiles against mock device
    inspec exec my-profile.rb -t juniper://mock
    ```

!!! tip "Mock Benefits"
    - :material-check: **No hardware required**
    - :material-check: **Realistic JunOS output** 
    - :material-check: **Perfect for CI/CD**
    - :material-check: **Safe for learning**

## Structured Output (Recommended)

For reliable parsing in InSpec profiles, use JSON or XML output:

```ruby
# Use JSON output for structured data parsing
describe json(command: 'show version | display json') do
  its(['software-information', 0, 'junos-version', 0, 'data']) { should match /\d+\.\d+/ }
end

# Or XML for complex configurations
describe xml(command: 'show configuration | display xml') do
  its('configuration/system/hostname') { should_not be_empty }
end
```

## Common Commands

These are the most useful JunOS commands for InSpec testing:

### Device Information
```bash
show version | display json              # Device software version (structured)
show chassis hardware | display json     # Hardware information (structured)
show system hostname                     # Device hostname
show system uptime                       # System uptime
```

### Configuration  
```bash
show configuration | display json        # Full configuration (structured)
show interfaces terse | display json     # Interface summary (structured)
show route summary                       # Routing table summary
```

### Status
```bash
show system alarms                       # System alarms
show log messages                        # System log messages
```

## Environment Variables

Configure connection settings using environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `JUNIPER_HOST` | Target device hostname | `fw1.example.com` |
| `JUNIPER_USER` | SSH username | `admin` |  
| `JUNIPER_PASSWORD` | SSH password | `your_password` |
| `JUNIPER_PORT` | SSH port (default: 22) | `2222` |
| `JUNIPER_BASTION_HOST` | Jump host | `jump.example.com` |
| `JUNIPER_BASTION_USER` | Jump host user | `bastion_user` |
| `TRAIN_DEBUG` | Enable debug logging | `true` |

## Troubleshooting

### Connection Issues

```bash
# Test basic SSH connectivity first
ssh admin@your-device.example.com "show version"

# Enable debug logging for train-juniper
TRAIN_DEBUG=true inspec detect -t juniper://admin@your-device.example.com
```

### Common Issues

**Connection refused**: Check if SSH is enabled on the device and port is correct.

**Authentication failed**: Verify username/password or SSH key permissions.

**Command timeout**: Increase timeout or check if device is responsive.

## Getting Help

- **GitHub Issues**: [Report bugs or ask questions](https://github.com/mitre/train-juniper/issues)
- **Documentation**: [Full documentation site](https://mitre.github.io/train-juniper/)
- **Email**: [saf@mitre.org](mailto:saf@mitre.org)
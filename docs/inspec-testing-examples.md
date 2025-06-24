# InSpec Testing Examples for train-juniper

This guide provides examples for testing Juniper devices using InSpec with the train-juniper plugin. These examples work with just the transport plugin installed - no custom resources required!

## Prerequisites

1. **Install train-juniper plugin**:
   ```bash
   gem install train-juniper
   ```

2. **For Windows users with bastion hosts**: Accept the bastion host key first (see [Windows Bastion Setup Guide](windows-bastion-setup.md)):
   ```powershell
   plink.exe -ssh your-username@your-bastion-host.com
   # Type 'y' to accept the host key, then exit
   ```

## Basic Connection Testing

### Test Direct Connection
```powershell
# Basic connection test
inspec detect -t juniper://admin@device.example.com --password 'your-password'

# With bastion host
inspec detect -t juniper://admin@device.example.com --password 'device-pass' `
  --bastion-host bastion.example.com `
  --bastion-user jumpuser
```

### Enable Debug Logging
```powershell
# Set debug environment variable
$env:TRAIN_JUNIPER_LOG_LEVEL = "debug"

# Run with debug output
inspec detect -t juniper://admin@device.example.com --password 'your-password' -l debug
```

## Using Structured Output (XML/JSON)

Juniper devices support structured output formats. InSpec has built-in `xml` and `json` resources for parsing this data.

### XML Examples (Recommended - Widely Supported)

#### One-liner Tests
```powershell
# Check device version
inspec exec -t juniper://admin@device.example.com --password 'pass' `
  -c "describe xml(command: 'show version | display xml') do; its('software-information/junos-version') { should match /23\.4/ }; end"

# Check SSH configuration
inspec exec -t juniper://admin@device.example.com --password 'pass' `
  -c "describe xml(command: 'show configuration system services ssh | display xml') do; its('configuration/system/services/ssh/connection-limit') { should cmp 10 }; end"

# Check if root login is restricted
inspec exec -t juniper://admin@device.example.com --password 'pass' `
  -c "describe xml(command: 'show configuration system root-authentication | display xml') do; its('configuration/system/root-authentication/encrypted-password') { should_not be_nil }; end"
```

#### Create a Test File
Save as `juniper_xml_test.rb`:
```ruby
# Test Juniper device using XML output
describe xml(command: 'show version | display xml') do
  its('software-information/host-name') { should_not be_nil }
  its('software-information/product-model') { should match /srx|mx|ex/i }
  its('software-information/junos-version') { should match /\d+\.\d+/ }
end

describe xml(command: 'show system uptime | display xml') do
  its('system-uptime-information/uptime-information/up-time/@seconds') { should cmp > 3600 }
end

describe xml(command: 'show configuration system services | display xml') do
  its('configuration/system/services/ssh') { should_not be_nil }
  its('configuration/system/services/ssh/connection-limit') { should cmp <= 10 }
  its('configuration/system/services/telnet') { should be_nil }  # Telnet should be disabled
end

describe xml(command: 'show configuration system login | display xml') do
  its('configuration/system/login/user[name="root"]/class') { should_not cmp 'super-user' }
end

# Check SNMP security
describe xml(command: 'show configuration snmp | display xml') do
  its('configuration/snmp/community[name="public"]') { should be_nil }
  its('configuration/snmp/community[name="private"]') { should be_nil }
end

# Check NTP configuration
describe xml(command: 'show configuration system ntp | display xml') do
  its('configuration/system/ntp/server') { should_not be_empty }
end

# Check interface status
describe xml(command: 'show interfaces terse | display xml') do
  its('interface-information/physical-interface[name="ge-0/0/0"]/oper-status') { should cmp 'up' }
end
```

Run the test:
```powershell
inspec exec juniper_xml_test.rb -t juniper://admin@device.example.com --password 'your-password'
```

### JSON Examples (If Supported by Device)

```powershell
# Check SSH configuration using JSON
inspec exec -t juniper://admin@device.example.com --password 'your-password' `
  -c "describe json(command: 'show configuration system services ssh | display json') do; its(['configuration', 'system', 'services', 'ssh', 'connection-limit']) { should cmp 10 }; end"

# Check system information
inspec exec -t juniper://admin@device.example.com --password 'your-password' `
  -c "describe json(command: 'show version | display json') do; its(['software-information', 0, 'junos-version']) { should match /23\.4/ }; end"
```

## Interactive Shell Testing

The InSpec shell allows you to explore and test interactively:

```powershell
# Start shell
inspec shell -t juniper://admin@device.example.com --password 'your-password'

# Once in shell, try these commands:
# Get raw command output
command('show version').stdout

# Parse XML output
xml(command: 'show version | display xml').params
xml(command: 'show version | display xml')['software-information']['host-name']

# Explore available data
xml(command: 'show system users | display xml').params.keys
xml(command: 'show configuration | display xml').params['configuration'].keys

# Test specific values
xml(command: 'show configuration system services ssh | display xml')['configuration']['system']['services']['ssh']['connection-limit']
```

## Basic Command Resource Examples

If you prefer working with text output:

```powershell
# One-liner to check version
inspec exec -t juniper://admin@device.example.com --password 'your-password' `
  -c "describe command('show version') do; its('stdout') { should match /Junos/ }; end"

# Check system uptime
inspec exec -t juniper://admin@device.example.com --password 'your-password' `
  -c "describe command('show system uptime') do; its('stdout') { should match /up \d+ days/ }; end"

# Check SSH service
inspec exec -t juniper://admin@device.example.com --password 'your-password' `
  -c "describe command('show configuration system services ssh') do; its('stdout') { should match /ssh/ }; end"
```

## Security-Focused Test Examples

Create `juniper_security_test.rb`:
```ruby
# STIG-style security checks
describe xml(command: 'show configuration system services ssh | display xml') do
  its('configuration/system/services/ssh/protocol-version') { should include 'v2' }
  its('configuration/system/services/ssh/max-sessions-per-connection') { should cmp 1 }
  its('configuration/system/services/ssh/connection-limit') { should cmp <= 10 }
  its('configuration/system/services/ssh/root-login') { should_not cmp 'allow' }
end

# Check syslog configuration
describe xml(command: 'show configuration system syslog | display xml') do
  its('configuration/system/syslog/host') { should_not be_nil }
  its('configuration/system/syslog/file[name="messages"]/archive/files') { should cmp >= 10 }
end

# Check authentication settings
describe xml(command: 'show configuration system authentication-order | display xml') do
  its('configuration/system/authentication-order') { should include 'tacplus' }
end

# Check login message
describe xml(command: 'show configuration system login message | display xml') do
  its('configuration/system/login/message') { should match /authorized/i }
end
```

## Platform Detection Test

```ruby
# Save as platform_test.rb
describe os.family do
  it { should eq 'juniper' }
end

describe os.release do
  it { should match /^\d+\.\d+/ }
end

describe os.arch do
  it { should eq 'x86_64' }
end
```

## Tips for Writing Tests

1. **Use Structured Output**: Always prefer `| display xml` or `| display json` over parsing text output
2. **XPath Syntax**: For XML, use `/` to navigate hierarchy, `[@attribute]` for attributes
3. **Nil Checks**: Use `should_not be_nil` to verify configuration exists
4. **Numeric Comparisons**: Use `cmp` instead of `eq` for numbers to handle type conversions
5. **Debug in Shell**: Use InSpec shell to explore data structure before writing tests

## With Custom Resources (In Development)

The InSpec resource pack is currently in development and will provide more intuitive syntax for testing Juniper devices. Here's what's coming:

### Available Resources (Preview)

```ruby
# juniper - System information resource
describe juniper do
  it { should exist }
  its('model') { should match /srx|mx|ex/i }
  its('version') { should match /23\.4/ }
  its('hostname') { should eq 'fw-datacenter-01' }
  its('uptime_seconds') { should be > 3600 }
end

# juniper_system_services - Service configurations
describe juniper_system_services do
  its('ssh.configured?') { should eq true }
  its('ssh.port') { should eq 22 }
  its('ssh.connection_limit') { should be <= 10 }
  its('ssh.max_sessions_per_connection') { should eq 1 }
  its('telnet.configured?') { should eq false }  # Should be disabled
  its('web_management.http.configured?') { should eq false }
  its('web_management.https.configured?') { should eq true }
end

# juniper_system_login - User accounts and authentication
describe juniper_system_login do
  it { should exist }
  its('users') { should include 'admin' }
  its('user_count') { should be > 0 }
  its('authentication_order') { should include 'tacplus' }
  its('authentication_order') { should include 'password' }
  
  # Check specific user properties
  its('user("admin").class') { should eq 'super-user' }
  its('user("root").class') { should_not eq 'super-user' }
end

# juniper_system_syslog - Syslog configuration
describe juniper_system_syslog do
  it { should exist }
  its('host_count') { should be > 0 }
  its('hosts') { should include '192.168.1.100' }
  its('file("messages").configured?') { should eq true }
  its('file("messages").archive.files') { should be >= 10 }
  its('console.configured?') { should eq false }  # Console logging should be disabled
end

# juniper_system_aaa - AAA/TACACS+ configuration
describe juniper_system_aaa do
  it { should exist }
  its('tacplus_servers') { should_not be_empty }
  its('tacplus_server("192.168.1.50").configured?') { should eq true }
  its('tacplus_server("192.168.1.50").port') { should eq 49 }
  its('tacplus_server("192.168.1.50").timeout') { should be <= 5 }
  its('accounting.configured?') { should eq true }
  its('accounting.events') { should include 'login' }
  its('accounting.events') { should include 'interactive-commands' }
end

# juniper_snmp - SNMP configuration
describe juniper_snmp do
  it { should exist }
  its('community("public").configured?') { should eq false }
  its('community("private").configured?') { should eq false }
  its('v3.configured?') { should eq true }
  its('v3.users') { should include 'snmpv3user' }
  its('trap_groups') { should_not be_empty }
end
```

### Real STIG Control Examples (From Resource Pack)

```ruby
# SV-223180: SSH connection limit
control 'SV-223180' do
  title 'The Juniper SRX Services Gateway must limit the number of concurrent sessions to a maximum of 10 or less for remote access using SSH.'
  desc 'Connection limit helps thwart brute force authentication attacks'
  
  describe juniper_system_services do
    its('ssh.connection_limit') { should be <= 10 }
    its('ssh.max_sessions_per_connection') { should eq 1 }
  end
end

# Check multiple security requirements
control 'juniper-security-baseline' do
  title 'Juniper Security Baseline Checks'
  
  # SSH hardening
  describe juniper_system_services do
    its('ssh.configured?') { should eq true }
    its('ssh.protocol_version') { should include 'v2' }
    its('ssh.root_login') { should_not eq 'allow' }
    its('telnet.configured?') { should eq false }
  end
  
  # Authentication requirements
  describe juniper_system_login do
    its('authentication_order') { should include 'tacplus' }
    its('user("root").class') { should_not eq 'super-user' }
    its('message') { should match /authorized|warning/i }
  end
  
  # Logging requirements  
  describe juniper_system_syslog do
    its('host_count') { should be > 0 }
    its('file("messages").configured?') { should eq true }
  end
end
```

### Interactive Shell Examples (Coming Soon)

```ruby
# Explore device configuration interactively
juniper.model
juniper.version
juniper.hostname

# Check services
juniper_system_services.methods
juniper_system_services.ssh.to_h
juniper_system_services.configured_services

# Explore users
juniper_system_login.users
juniper_system_login.user('admin').class
juniper_system_login.user('admin').uid

# Check syslog destinations
juniper_system_syslog.hosts
juniper_system_syslog.files
juniper_system_syslog.file('messages').to_h
```

### Running STIG Profiles (Coming Soon)

```powershell
# Run complete STIG baseline
inspec exec https://github.com/mitre/juniper-srx-ndm-stig-baseline `
  -t juniper://admin@device.example.com --password 'your-password'

# Run with customization
inspec exec https://github.com/mitre/juniper-srx-ndm-stig-baseline `
  -t juniper://admin@device.example.com --password 'your-password' `
  --input admin_users='["admin", "netops"]' `
  --input syslog_hosts='["192.168.1.100", "192.168.1.101"]'
```

### Resource Pack Installation (When Available)

```bash
# Install from RubyGems (future)
inspec plugin install inspec-juniper-resources

# Or install from GitHub
git clone https://github.com/mitre/inspec-juniper-resources
inspec plugin install inspec-juniper-resources/
```

The resource pack will provide:
- Natural language syntax for tests
- Automatic XML parsing and error handling
- Cached command results for performance
- Helper methods for common tasks
- Full STIG baseline coverage

## Troubleshooting

1. **Connection Timeout**: Increase timeout with `--connection-timeout 60`
2. **XML Parse Errors**: Some commands may not support XML output - use text output instead
3. **Permission Denied**: Ensure your user has necessary privileges to run show commands
4. **Bastion Issues**: On Windows, ensure you've accepted the bastion host key with plink first

## Next Steps

- Explore more Juniper commands with `| display xml` to discover available data
- Write profile-specific tests for your environment
- Consider contributing test examples back to the project
- Watch for the InSpec resource pack release for simpler syntax
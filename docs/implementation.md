# Train-Juniper Plugin Implementation Plan

## Project Overview

This document outlines the comprehensive plan for implementing a Train plugin to support Juniper Networks JunOS devices, enabling InSpec compliance testing and automation for Juniper routers, switches, and firewalls.

## Executive Summary

**Objective**: Create `train-juniper` plugin to provide unified transport interface for Juniper JunOS devices
**Approach**: Standalone Train plugin (not core PR) 
**Timeline**: 6-8 weeks for full implementation
**Dependencies**: Modern Ruby gems for SSH, NETCONF, and Juniper automation

## Research Findings

### Train Architecture Analysis

**Plugin System:**
- Plugin-based transport architecture with unified API (`run_command`, `file`, `os`)
- Platform detection system using hierarchical family structure
- Existing network device precedent: Cisco IOS family support
- Clean separation between transport (connection) and platform (detection)

**Existing Network Device Support:**
- Cisco IOS implementation in `lib/train/transports/cisco_ios_connection.rb`
- SSH-based with device-specific prompt handling and error detection
- Platform detection via `show version` command parsing
- Enable mode escalation and terminal configuration

### Community Plugin Analysis

Based on analysis of successful community plugins from Prospectra and others:

**Common Patterns:**
```ruby
# Standard plugin structure
module TrainPlugins
  module PluginName
    class Transport < Train.plugin(1)
      name "plugin-name"
      option :option_name, required: true, default: value
      
      def connection(_instance_opts = nil)
        @connection ||= TrainPlugins::PluginName::Connection.new(@options)
      end
    end
  end
end
```

**Key Examples:**
- **train-rest**: REST API abstraction with authentication handlers
- **train-telnet**: Direct telnet support with Net::Telnet integration
- **train-awsssm**: AWS Systems Manager without SSH/WinRM
- **train-serial**: Serial/USB device connectivity

### Juniper Automation Ecosystem

**Primary Protocols:**
1. **NETCONF over SSH** (Port 830) - Structured XML, transaction support
2. **REST API** - JSON/XML over HTTPS (modern JunOS versions)
3. **SSH CLI** - Traditional command-line interface

**Ruby Libraries:**
- **`net-netconf`** - Core NETCONF support from Juniper
- **`junos-ez-stdlib`** - High-level JunOS automation framework  
- **`net-ssh-telnet`** - Telnet-like interface over SSH (perfect for Train)
- **`expect4r`** - Network device CLI automation (Cisco/Juniper)

**Connection Handling:**
- **net-ssh-telnet** provides ideal SSH prompt handling for Train integration
- **expect4r** demonstrates proven Juniper CLI automation patterns
- **boxen** shows modern containerized testing approaches

## Implementation Strategy

### Phase 1: Core Plugin Foundation (2 weeks)

**Deliverables:**
- Basic train-juniper gem structure
- SSH-based connection with net-ssh-telnet
- Platform detection for JunOS devices
- Basic command execution

**Technical Approach:**
```ruby
# lib/train-juniper/connection.rb
class JuniperConnection < Train::Plugins::Transport::BaseConnection
  def initialize(options)
    super
    require 'net/ssh/telnet'
    @juniper_prompt = /^[^@]+@[^>]+[>#]\s*$/
  end

  def session
    return @session if @session
    
    ssh_conn = establish_connection
    @session = Net::SSH::Telnet.new(
      "Session" => ssh_conn,
      "Prompt" => @juniper_prompt,
      "Timeout" => @options[:command_timeout] || 10
    )
    
    configure_junos_session
    @session
  end

  def run_command_via_connection(cmd, &_data_handler)
    logger.debug("[JUNIPER] Running `#{cmd}`")
    result = session.cmd(cmd)
    format_junos_result(result, cmd)
  rescue => e
    raise Train::TransportError, "Juniper command failed: #{e.message}"
  end

  private

  def configure_junos_session
    # Optimize for automation
    session.cmd('set cli screen-length 0')
    session.cmd('set cli screen-width 0') 
    session.cmd('set cli complete-on-space off') if @options[:disable_complete_on_space]
  end

  def format_junos_result(output, cmd)
    # Parse JunOS-specific error patterns
    if junos_error?(output)
      CommandResult.new("", output, 1)
    else
      CommandResult.new(clean_output(output, cmd), "", 0)
    end
  end

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
end
```

### Phase 2: Enhanced Features (2 weeks)

**NETCONF Integration:**
```ruby
# lib/train-juniper/netconf_connection.rb
class NetconfConnection < JuniperConnection
  def initialize(options)
    super
    require 'net/netconf'
    @netconf_enabled = options[:enable_netconf] != false
  end

  def netconf_session
    return @netconf_session if @netconf_session
    
    if @netconf_enabled
      @netconf_session = Netconf::SSH.new(@options)
    end
  end

  def get_config(source = 'running')
    return super unless netconf_session
    
    result = netconf_session.rpc.get_config(source: source)
    format_netconf_result(result)
  end

  def commit_config(comment: nil, confirmed: false)
    return super unless netconf_session
    
    opts = {}
    opts[:log] = comment if comment
    opts[:confirmed] = confirmed if confirmed
    
    netconf_session.rpc.commit_configuration(opts)
  end
end
```

**Platform Detection:**
```ruby
# Platform detection for JunOS
def juniper_show_version
  cmd = @backend.run_command("show version | no-more")
  return false if cmd.exit_status != 0
  
  output = cmd.stdout
  if output.match(/JUNOS|Juniper Networks/i)
    @platform[:release] = extract_junos_version(output)
    @platform[:arch] = extract_junos_platform(output)
    { type: "junos", version: @platform[:release] }
  else
    false
  end
end

def extract_junos_version(output)
  # Extract version from "JUNOS Base OS boot [15.1X49-D160.2]"
  output[/JUNOS.*\[([\d\w\.-]+)\]/, 1] || 
  output[/Junos:\s+([\d\w\.-]+)/, 1] ||
  "unknown"
end
```

### Phase 3: Configuration Management (2 weeks)

**JunOS Configuration Support:**
```ruby
# lib/train-juniper/config_manager.rb
class ConfigManager
  def initialize(connection)
    @connection = connection
  end

  def load_config(config_text, format: :text, replace: false)
    if @connection.netconf_session
      load_via_netconf(config_text, format, replace)
    else
      load_via_cli(config_text, replace)
    end
  end

  def commit(comment: nil, confirmed: false, confirm_timeout: 10)
    if @connection.netconf_session
      @connection.commit_config(comment: comment, confirmed: confirmed)
    else
      cmd = "commit"
      cmd += " comment \"#{comment}\"" if comment
      cmd += " confirmed #{confirm_timeout}" if confirmed
      @connection.run_command(cmd)
    end
  end

  def rollback(rollback_id = 0)
    if @connection.netconf_session
      @connection.netconf_session.rpc.load_configuration(
        rollback: rollback_id
      )
    else
      @connection.run_command("rollback #{rollback_id}")
    end
  end

  private

  def load_via_cli(config_text, replace)
    @connection.run_command("configure")
    @connection.run_command("load #{replace ? 'replace' : 'merge'} terminal")
    @connection.run_command(config_text)
    @connection.run_command("\x04")  # Ctrl+D to end input
  end
end
```

### Phase 4: Testing & InSpec Integration (2 weeks)

**Test Infrastructure:**
```ruby
# test/integration/juniper_integration_test.rb
describe 'Juniper Integration Tests' do
  let(:connection) do
    Train.create('juniper', 
      host: ENV['JUNIPER_HOST'],
      user: ENV['JUNIPER_USER'], 
      password: ENV['JUNIPER_PASSWORD'],
      enable_netconf: true
    ).connection
  end

  it 'detects JunOS platform' do
    expect(connection.os.family).to eq('juniper')
    expect(connection.os.name).to eq('junos')
  end

  it 'executes show commands' do
    result = connection.run_command('show version')
    expect(result.exit_status).to eq(0)
    expect(result.stdout).to match(/JUNOS/)
  end

  it 'supports configuration mode' do
    result = connection.run_command('configure')
    expect(result.exit_status).to eq(0)
  end
end
```

**Boxen Integration for CI/CD:**
```yaml
# .github/workflows/test.yml
name: Test train-juniper
on: [push, pull_request]

jobs:
  integration:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup containerlab
        run: |
          sudo containerlab deploy -t test/fixtures/juniper-lab.yml
      - name: Run integration tests
        run: |
          bundle exec rake test:integration
```

## Project Structure

```
train-juniper/
├── lib/
│   ├── train-juniper.rb              # Main entry point
│   └── train-juniper/
│       ├── version.rb                # Version constant
│       ├── transport.rb              # Transport class
│       ├── connection.rb             # Base connection
│       ├── netconf_connection.rb     # NETCONF support
│       ├── config_manager.rb         # Configuration management
│       └── platform.rb              # Platform detection helpers
├── test/
│   ├── unit/                         # Unit tests
│   ├── integration/                  # Integration tests
│   └── fixtures/                     # Test fixtures
├── examples/                         # Usage examples
├── docs/                            # Documentation
├── train-juniper.gemspec            # Gem specification
├── Gemfile                          # Development dependencies
├── Rakefile                         # Build tasks
└── README.md                        # Project documentation
```

## Dependencies

```ruby
# train-juniper.gemspec
spec.add_dependency "train", "~> 3.13"
spec.add_dependency "net-ssh-telnet", "~> 0.1"
spec.add_dependency "net-netconf", "~> 0.6"

# Optional advanced features
spec.add_dependency "junos-ez-stdlib", "~> 2.0" if RUBY_VERSION >= "2.7"

# Development/testing
spec.add_development_dependency "rspec", "~> 3.12"
spec.add_development_dependency "webmock", "~> 3.18"
```

## Transport Options

```ruby
# Connection options
option :host, required: true
option :user, default: "admin", required: true  
option :password, default: nil
option :port, default: 22
option :netconf_port, default: 830

# JunOS specific options
option :enable_netconf, default: true
option :netconf_timeout, default: 30
option :commit_timeout, default: 60
option :disable_complete_on_space, default: true

# CLI behavior
option :cli_prompt, default: /^[^@]+@[^>]+[>#]\s*$/
option :config_prompt, default: /^[^@]+@[^%]+[%#]\s*$/
option :command_timeout, default: 10
```

## Platform Detection Integration

```ruby
# Add to train/platforms/detect/specifications/os.rb
plat.family("juniper").title("Juniper Networks Family").in_family("os")
  .detect do
    juniper_show_version
  end

declare_cisco("juniper_junos", "Juniper JunOS", "juniper", :juniper_show_version, "junos")

declare_instance("juniper_srx", "Juniper SRX", "juniper") do
  v = juniper_show_version
  next unless v && v[:type] == "junos"
  
  model_info = @backend.run_command("show chassis hardware | no-more").stdout
  if model_info.match?(/SRX/i)
    @platform[:model] = extract_srx_model(model_info)
    true
  end
end
```

## Future InSpec Resource Pack

```ruby
# inspec-juniper gem structure
inspec-juniper/
├── lib/
│   └── inspec-juniper/
│       ├── resources/
│       │   ├── junos_interface.rb    # Interface configuration
│       │   ├── junos_routing.rb      # Routing table inspection  
│       │   ├── junos_security.rb     # Security policies
│       │   └── junos_system.rb       # System configuration
│       └── matchers/                 # Custom matchers
└── examples/                         # Example profiles

# Example resource usage
describe junos_interface('ge-0/0/0') do
  it { should be_enabled }
  its('mtu') { should eq 1500 }
  its('description') { should match /WAN/ }
end

describe junos_security_policy('trust-to-untrust') do
  it { should exist }
  its('action') { should eq 'permit' }
end
```

## Risk Mitigation

**Technical Risks:**
- **NETCONF compatibility**: Test across JunOS versions 15.1+ 
- **Prompt detection**: Extensive testing of CLI prompt variations
- **Authentication**: Support key-based and password authentication

**Operational Risks:**
- **Device compatibility**: Test on SRX, EX, MX, QFX platforms
- **Version support**: Support JunOS 15.1+ (current widespread deployment)
- **Performance**: Optimize for large-scale InSpec scanning

## Success Metrics

**Functional Goals:**
- [ ] SSH connectivity to JunOS devices
- [ ] Platform detection and version identification  
- [ ] Command execution with proper error handling
- [ ] NETCONF support for configuration management
- [ ] InSpec resource pack foundation

**Quality Metrics:**
- [ ] >90% test coverage
- [ ] CI/CD pipeline with containerized testing
- [ ] Documentation with examples
- [ ] Community adoption (GitHub stars/downloads)

## Timeline & Milestones

**Week 1-2: Core Foundation**
- Project setup and basic SSH connectivity
- Platform detection implementation
- Basic command execution

**Week 3-4: Enhanced Features**  
- NETCONF integration
- Configuration management
- Error handling refinement

**Week 5-6: Testing & Polish**
- Comprehensive test suite
- CI/CD pipeline setup
- Documentation completion

**Week 7-8: InSpec Integration**
- Basic InSpec resources
- Example profiles
- Community preview release

This implementation plan provides a comprehensive roadmap for creating production-ready Juniper support for the Train ecosystem while following established community patterns and best practices.
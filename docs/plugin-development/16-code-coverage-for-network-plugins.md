# Code Coverage Strategies for Train Plugin Ecosystem

## Module Overview

Different types of Train plugins face unique testing challenges that significantly affect achievable code coverage. This module provides coverage strategies, realistic targets, and testing approaches for each major plugin category in the Train ecosystem.

## The Network Plugin Coverage Challenge

### Traditional Application vs Network Plugin Testing

**Traditional Applications:**
- Mock external APIs easily
- Simulate database connections
- Test all code paths in isolation
- Achieve 90%+ coverage readily

**Network Device Plugins:**
- Require real SSH connections
- Device-specific behaviors vary by firmware
- Enterprise network infrastructure dependencies
- Practical coverage ceiling of 80-85%

## Train Plugin Ecosystem Coverage Analysis

### Plugin Categories and Coverage Expectations

| Plugin Category | Coverage Target | Real Examples | Key Challenges |
|-----------------|-----------------|---------------|----------------|
| **API-based Cloud** | 85-95% (estimated) | train-aws, train-azure, train-gcp | HTTP mocking, auth flows |
| **SSH/Local System** | 90-95% (estimated) | train-ssh, train-local | Easy to mock, well-established |
| **Network Devices** | 75-85% (train-juniper: 81.57%) | train-cisco-ios, train-juniper, train-telnet | SSH+hardware dependencies |
| **Container Platforms** | 80-90% (estimated) | train-docker, train-k8s-container, train-kubernetes | API + system calls mix |
| **Windows Automation** | 75-85% (estimated) | train-winrm, train-pwsh | Protocol-specific behavior |
| **Virtualization** | 80-90% (estimated) | train-vmware | Mixed API/system dependencies |
| **Specialized Transport** | 70-85% (estimated) | train-rest, train-awsssm | Protocol boundary challenges |

**Note:** Coverage targets are estimates based on architectural analysis except where noted. Only train-juniper has measured coverage from our implementation.

### Detailed Category Analysis

#### **1. API-based Cloud Plugins (85-95% target)**

**Examples:** train-aws, train-azure, train-gcp, train-alicloud

**Easily Testable:**
```ruby
# HTTP API calls can be mocked effectively
def list_instances
  response = aws_client.describe_instances
  parse_instance_data(response.reservations)  # ✅ 100% testable
end

# Authentication and credential handling
def authenticate
  validate_credentials(@options)  # ✅ Testable with mock credentials
  setup_session(@options)        # ✅ Mockable
end
```

**Challenging Areas:**
```ruby
# Real AWS SDK initialization (5-10% uncovered)
def aws_client
  @aws_client ||= Aws::EC2::Client.new(
    region: @options[:region],
    credentials: aws_credentials,
    # SDK internals can't be fully mocked
  )
end

# Rate limiting and retry logic (requires real API errors)
def handle_api_throttling
  sleep(exponential_backoff_delay)  # Hard to test timing
  retry_request                     # Needs real throttling
end
```

**Coverage Strategy:**
- Mock all HTTP interactions with VCR or similar
- Test business logic with fixture data
- Accept uncovered SDK initialization and retry mechanics

#### **2. SSH/Local System Plugins (90-95% target)**

**Examples:** train-ssh, train-local

**Easily Testable:**
```ruby
# Command parsing and result formatting
def parse_command_output(stdout, stderr, exit_code)
  if exit_code == 0
    format_success_result(stdout)  # ✅ 100% testable
  else
    format_error_result(stderr)    # ✅ 100% testable  
  end
end

# File operations abstraction
def file_exists?(path)
  command_result = run_command("test -f #{path}")
  command_result.exit_status == 0  # ✅ Testable with mock commands
end
```

**Challenging Areas:**
```ruby
# Real SSH connection establishment (5-10% uncovered)
def establish_ssh_connection
  Net::SSH.start(@options[:host], @options[:user], ssh_options)
  # Actual network calls can't be unit tested
end

# System-specific behavior (varies by OS)
def detect_os
  uname_result = run_command("uname -a")  # May behave differently on test vs prod
  parse_uname_output(uname_result.stdout)
end
```

**Coverage Strategy:**
- Mock command execution at the boundary
- Test all parsing and formatting logic
- Use test doubles for SSH connections

#### **3. Network Device Plugins (75-85% target)**

**Examples:** train-cisco-ios, train-juniper, train-f5

**Testable Business Logic:**
```ruby
# Device output parsing (should be 100% covered)
def parse_interface_config(show_interface_output)
  interfaces = {}
  current_interface = nil
  
  show_interface_output.split("\n").each do |line|
    if line.match(/^interface (\S+)/)
      current_interface = $1
      interfaces[current_interface] = {}
    elsif current_interface && line.match(/\s+ip address (\S+) (\S+)/)
      interfaces[current_interface][:ip] = $1
      interfaces[current_interface][:netmask] = $2
    end
  end
  
  interfaces  # ✅ Fully testable with mock device output
end

# Error pattern detection
def device_error?(output)
  ERROR_PATTERNS.any? { |pattern| output.match?(pattern) }  # ✅ Testable
end
```

**Infrastructure Dependencies:**
```ruby
# SSH to network devices (15-25% uncovered)
def connect_to_device
  @ssh_session = Net::SSH.start(@options[:host], @options[:user], {
    password: @options[:password],
    port: @options[:port] || 22,
    timeout: @options[:timeout] || 30
  })
  # Requires actual network device
end

# Device-specific session configuration
def configure_device_session
  run_command("terminal length 0")      # Device-specific
  run_command("terminal width 0")       # May vary by model/firmware
  run_command("no logging console")     # Some devices don't support
end
```

**Coverage Strategy:**
- Comprehensive mock mode for all business logic
- Accept SSH connectivity as uncovered
- Document device-specific behaviors

#### **4. Container Platform Plugins (80-90% target)**

**Examples:** train-docker, train-kubernetes, train-podman

**Easily Testable:**
```ruby
# Container metadata parsing
def parse_container_info(docker_inspect_json)
  container_data = JSON.parse(docker_inspect_json)
  {
    id: container_data['Id'],
    name: container_data['Name'],
    image: container_data['Config']['Image'],
    status: container_data['State']['Status']
  }  # ✅ 100% testable with JSON fixtures
end

# Command construction
def build_docker_command(action, container_id, options = {})
  cmd = ["docker", action, container_id]
  cmd += ["--format", "json"] if options[:json]
  cmd.join(" ")  # ✅ Fully testable
end
```

**System Dependencies:**
```ruby
# Docker daemon communication (10-20% uncovered)
def docker_client
  Docker::Connection.new(@options[:socket_path] || '/var/run/docker.sock')
  # Requires Docker daemon running
end

# Container execution
def exec_in_container(container_id, command)
  container = docker_client.containers.get(container_id)
  container.exec(command)  # Needs real container runtime
end
```

**Coverage Strategy:**
- Mock Docker API responses with fixtures
- Test command construction and response parsing
- Accept runtime dependencies as uncovered

#### **5. Database System Plugins (85-95% target)**

**Examples:** train-postgresql, train-mysql, train-oracle

**Highly Testable:**
```ruby
# Query result processing
def process_query_results(result_set)
  rows = []
  result_set.each do |row|
    processed_row = {}
    row.each_with_index do |value, index|
      column_name = result_set.fields[index]
      processed_row[column_name.to_sym] = value
    end
    rows << processed_row
  end
  rows  # ✅ 100% testable with mock result sets
end

# SQL query construction
def build_user_query(username = nil)
  query = "SELECT username, uid, gid, home, shell FROM users"
  query += " WHERE username = '#{username}'" if username
  query  # ✅ Fully testable
end
```

**Connection Dependencies:**
```ruby
# Database connection establishment (5-15% uncovered)
def database_connection
  PG.connect(
    host: @options[:host],
    port: @options[:port] || 5432,
    dbname: @options[:database],
    user: @options[:username],
    password: @options[:password]
  )
  # Requires running database server
end

# Connection pooling and retry logic
def with_retry(&block)
  retries = 3
  begin
    yield
  rescue PG::ConnectionBad => e
    retries -= 1
    retry if retries > 0
    raise
  end
end
```

**Coverage Strategy:**
- Mock database connections and result sets
- Test all SQL generation and result processing
- Use test databases for integration testing

#### **6. Specialized Protocol Plugins (70-85% target)**

**Examples:** train-winrm, train-telnet, train-snmp

**Protocol-Agnostic Logic:**
```ruby
# Command result interpretation
def interpret_winrm_result(result)
  {
    stdout: result.output,
    stderr: result.stderr,
    exit_code: result.exit_code
  }  # ✅ Testable with mock WinRM results
end

# Protocol-specific formatting
def format_powershell_command(command)
  "powershell.exe -Command \"& {#{command}}\""  # ✅ Fully testable
end
```

**Protocol Dependencies:**
```ruby
# WinRM session establishment (15-30% uncovered)
def winrm_connection
  WinRM::Connection.new(
    endpoint: "http://#{@options[:host]}:5985/wsman",
    user: @options[:user],
    password: @options[:password],
    transport: :negotiate
  )
  # Requires Windows target with WinRM enabled
end

# Protocol-specific authentication
def authenticate_kerberos
  # Complex authentication flows
  # Environment-specific configuration
  # Hard to mock completely
end
```

**Coverage Strategy:**
- Mock protocol interactions at the boundary
- Test command formatting and response parsing
- Accept authentication flows as partially uncovered

## Coverage Strategy Framework

### 1. Categorize Your Code Paths

#### **Mock-Testable (Target: 100% coverage)**
```ruby
# Command parsing and result formatting
def parse_version_output(output)
  patterns = [
    /Junos:\s+([\d\w\.-]+)/,
    /JUNOS Software Release \[([\d\w\.-]+)\]/
  ]
  # This CAN be fully tested with string inputs
end

# Error pattern detection  
def junos_error?(output)
  JUNOS_ERROR_PATTERNS.any? { |pattern| output.match?(pattern) }
  # This CAN be fully tested with mock error outputs
end
```

#### **Infrastructure-Dependent (Accept as uncovered)**
```ruby
# Real SSH connections
def connect
  @ssh_session = Net::SSH.start(@options[:host], @options[:user], ssh_options)
  # This CANNOT be unit tested without real devices
end

# Enterprise proxy setup
def setup_proxy_connection
  return Net::SSH::Proxy::Command.new(proxy_command)
  # This CANNOT be tested without bastion infrastructure
end
```

### 2. Design Mock-First Architecture

#### **Good: Testable Design**
```ruby
class Connection < BaseConnection
  def run_command_via_connection(cmd)
    return mock_command_result(cmd) if @options[:mock]  # ✅ Testable path
    
    # Real SSH execution (uncovered, but isolated)
    execute_real_command(cmd)
  end
  
  private
  
  def mock_command_result(cmd)
    # All business logic here - fully testable
    case cmd
    when /show version/
      parse_version_output(mock_version_data)
    end
  end
end
```

#### **Bad: Untestable Design**
```ruby
class Connection < BaseConnection
  def run_command_via_connection(cmd)
    # Mixed real and mock logic - hard to test
    if @options[:mock]
      return "mock data"
    else
      ssh_result = @ssh_session.exec!(cmd)  # Can't test this path
      parsed = parse_result(ssh_result)     # Can't test this either
      return formatted_result(parsed)      # Or this
    end
  end
end
```

### 3. Coverage Analysis Techniques

#### **Identify Uncovered Code Categories**

```ruby
# Run coverage analysis
bundle exec rake test
# Generate detailed line-by-line report

# Categorize uncovered lines:
coverage_data = JSON.parse(File.read('coverage/.resultset.json'))
uncovered_lines = find_uncovered_lines(coverage_data)

categorize_uncovered_code(uncovered_lines)
# => {
#   ssh_connections: [92, 94, 97, 144, 145],
#   proxy_setup: [230, 231, 232, 233], 
#   error_handling: [58, 59, 173, 185],
#   session_mgmt: [320, 321, 325, 326]
# }
```

#### **Document Acceptable Gaps**
```markdown
## Coverage Analysis: 81.57% (Target: 80%+)

### Uncovered Code (18.43% - Expected for Network Plugins)

**SSH Connection Logic (25 lines)** - Lines 92-155
- Net::SSH.start() calls require real devices
- Connection error handling needs actual network failures  
- SSH key authentication workflows need real key files

**Enterprise Infrastructure (4 lines)** - Lines 230-233  
- Bastion host setup requires corporate network access
- ProxyCommand testing needs SSH jump hosts

**Conclusion:** Coverage exceeds industry standard for network plugins.
```

## Implementation Examples

### Example 1: Version Detection with High Coverage

```ruby
# lib/train-device/platform.rb
module Platform
  def detect_version
    return nil if @options[:mock] || !connected?
    
    begin
      result = run_command_via_connection("show version")
      return nil unless result.exit_status == 0
      
      # This business logic is 100% testable
      extract_version_from_output(result.stdout)
    rescue => e
      # This error handling might be uncovered (requires real failures)
      logger&.debug("Version detection failed: #{e.message}")
      nil
    end
  end
  
  private
  
  # 100% testable with string inputs
  def extract_version_from_output(output)
    return nil if output.nil? || output.empty?
    
    patterns = [
      /Device OS:\s+([\d\w\.-]+)/,
      /Software Version\s+([\d\w\.-]+)/,
      /Version:\s+([\d\w\.-]+)/
    ]
    
    patterns.each do |pattern|
      match = output.match(pattern)
      return match[1] if match
    end
    
    nil
  end
end

# test/unit/platform_test.rb - 100% coverage of business logic
describe "version extraction" do
  let(:platform) { MockConnection.new.extend(Platform) }
  
  it "extracts version from standard format" do
    output = "Device OS: 15.4.2"
    version = platform.send(:extract_version_from_output, output)
    _(version).must_equal("15.4.2")
  end
  
  it "handles multiple version formats" do
    formats = [
      "Software Version 12.1.3",
      "Version: 20.4R1.12", 
      "Device OS: 8.0.1"
    ]
    
    formats.each do |format|
      version = platform.send(:extract_version_from_output, format)
      _(version).wont_be_nil
    end
  end
  
  it "returns nil for invalid output" do
    invalid_outputs = ["", nil, "No version info", "Error: command failed"]
    
    invalid_outputs.each do |output|
      version = platform.send(:extract_version_from_output, output)
      _(version).must_be_nil
    end
  end
end
```

### Example 2: Command Execution with Realistic Coverage

```ruby
# lib/train-device/connection.rb
class Connection < BaseConnection
  def run_command_via_connection(cmd)
    return mock_command_result(cmd) if @options[:mock]
    
    # This section will be uncovered (requires real SSH)
    begin
      connect unless connected?
      result = @ssh_connection.run_command(cmd)
      format_device_result(result, cmd)
    rescue => e
      logger.error("Command execution failed: #{e.message}")
      CommandResult.new("", 1, e.message)
    end
  end
  
  private
  
  # 100% testable - all business logic
  def mock_command_result(cmd)
    case cmd
    when /show version/
      format_device_result(mock_version_result, cmd)
    when /show config/
      format_device_result(mock_config_result, cmd)
    when /show interface/
      format_device_result(mock_interface_result, cmd)
    else
      CommandResult.new("% Unknown command: #{cmd}", 1)
    end
  end
  
  # 100% testable with mock inputs
  def format_device_result(raw_result, original_cmd)
    if device_error?(raw_result.stdout)
      CommandResult.new("", 1, raw_result.stdout)
    else
      cleaned_output = clean_command_output(raw_result.stdout, original_cmd)
      CommandResult.new(cleaned_output, 0, "")
    end
  end
  
  # 100% testable
  def device_error?(output)
    ERROR_PATTERNS.any? { |pattern| output.match?(pattern) }
  end
  
  # 100% testable  
  def clean_command_output(output, cmd)
    lines = output.split("\n")
    lines.reject! { |line| line.strip == cmd.strip }
    lines.join("\n")
  end
end

# test/unit/connection_test.rb - High coverage of business logic
describe "command execution" do
  let(:connection) { Connection.new(mock: true, host: "test.device") }
  
  it "handles show version commands" do
    result = connection.run_command_via_connection("show version")
    _(result.exit_status).must_equal(0)
    _(result.stdout).must_include("Mock Device")
  end
  
  it "detects device error patterns" do
    # Test with mock error outputs
    error_outputs = [
      "% Invalid command",
      "Error: syntax error", 
      "Command not found"
    ]
    
    error_outputs.each do |error_output|
      mock_result = MockResult.new(error_output, 0)
      result = connection.send(:format_device_result, mock_result, "test")
      _(result.exit_status).must_equal(1)
    end
  end
  
  it "cleans command output correctly" do
    raw_output = "show version\nDevice: Router\nVersion: 1.0\nshow version\n> "
    cleaned = connection.send(:clean_command_output, raw_output, "show version")
    _(cleaned).must_equal("Device: Router\nVersion: 1.0")
  end
end
```

## Universal Best Practices for Train Plugin Coverage

### 1. **Plugin Category-Aware Design**
- **Know your category's constraints:** API-based vs protocol-based vs hardware-dependent
- **Set realistic targets:** Don't chase 95% coverage on network device plugins
- **Design boundaries correctly:** Separate business logic from infrastructure dependencies

### 2. **Mock-First Architecture Patterns**

#### **Cloud/API Plugins:**
```ruby
class CloudConnection
  def list_resources
    return mock_resources if @options[:mock]
    # Real API call - accept as partially uncovered
    client.list_instances
  end
  
  private
  
  def mock_resources
    # All business logic here - target 100% coverage
    parse_resource_list(fixture_data)
  end
end
```

#### **Network Device Plugins:**
```ruby  
class NetworkConnection
  def run_command_via_connection(cmd)
    return mock_command_result(cmd) if @options[:mock]
    # SSH execution - expect 15-25% uncovered
    execute_real_command(cmd)
  end
  
  private
  
  def mock_command_result(cmd)
    # Device-specific parsing - target 100% coverage
    parse_device_output(mock_device_data[cmd])
  end
end
```

#### **Database Plugins:**
```ruby
class DatabaseConnection
  def query(sql)
    return mock_query_result(sql) if @options[:mock]
    # DB connection - accept 5-15% uncovered
    execute_real_query(sql)
  end
  
  private
  
  def mock_query_result(sql)
    # SQL parsing and result processing - target 100% coverage
    process_query_results(fixture_query_data[sql])
  end
end
```

### 3. **Category-Specific Coverage Strategies**

#### **High Coverage Categories (85-95%)**
- **API-based Cloud:** Mock HTTP calls, test business logic thoroughly
- **SSH/Local:** Mock command execution, test all parsing logic  
- **Database:** Mock connections, test SQL generation and processing

#### **Medium Coverage Categories (80-90%)**
- **Container Platforms:** Mock runtime APIs, test orchestration logic
- **Virtualization:** Mock hypervisor APIs, test resource management

#### **Lower Coverage Categories (70-85%)**
- **Network Devices:** Comprehensive mock mode, accept SSH as uncovered
- **Specialized Protocols:** Mock protocol boundaries, test formatting logic

### 4. **Coverage Analysis Framework**

#### **Ecosystem-Wide Coverage Checklist**
```ruby
# For ANY Train plugin, aim for 100% coverage of:

✅ **Business Logic**
- Data parsing and formatting
- Error pattern detection  
- Configuration validation
- Result transformation

✅ **Mock Mode Operations**
- Mock data generation
- Fixture processing
- Test scenario handling

⚠️ **Accept Partial Coverage**
- Real network connections
- External service initialization
- System-dependent behaviors
- Authentication flows

❌ **Red Flags (Fix These)**
- Parsing logic uncovered
- Validation methods untested
- Error handling gaps
- Configuration processing missing
```

### 5. **Documentation Standards for All Categories**

#### **Coverage Report Template**
```markdown
## Coverage Analysis: [X.X]% (Target: [Category Target]%)

### Plugin Category: [API-based Cloud/Network Device/etc.]
**Industry Benchmark:** [XX-XX]% for this category

### Covered Areas ([XX]% - Target 100% of testable logic)
✅ Business logic and data processing
✅ Mock mode operations  
✅ Configuration handling
✅ Error pattern detection

### Uncovered Areas ([XX]% - Expected for [Category])
⚠️ **[Infrastructure type]** (X lines) - [Reason]
⚠️ **[Connection type]** (X lines) - [Reason]  
⚠️ **[Protocol/API specific]** (X lines) - [Reason]

### Conclusion
Coverage meets/exceeds industry standard for [category] plugins.
All business logic tested. Infrastructure dependencies documented.
```

## Real-World Examples from Train Ecosystem

### **train-juniper (Network Device) - 81.57% coverage**
**Status:** ✅ **Measured - Production Implementation**
- **Covered:** Device output parsing, error detection, configuration handling, platform detection
- **Uncovered:** SSH connections (25 lines), proxy setup (4 lines), session management (7 lines), platform errors (2 lines)
- **Strategy:** Comprehensive mock mode, device output fixtures, integration testing
- **Architecture:** 4-file Train Plugin API v1, net-ssh-telnet for connectivity

### **train-cisco-ios (Network Device) - Coverage Unknown**
**Status:** ⚠️ **Built-in but undocumented**
- **Type:** Network device plugin (similar challenges to train-juniper)
- **Expected Coverage:** 75-85% based on architectural analysis
- **Architecture:** SSH-based connectivity to Cisco IOS/IOS-XE devices
- **Note:** Available as `ios://` URI scheme but lacks public documentation

### **train-rest (API Transport) - Coverage Unknown** 
**Status:** ✅ **Active community plugin (Prospectra)**
- **Type:** Generic REST API transport for web services
- **Expected Coverage:** 85-95% based on HTTP mockability
- **Architecture:** HTTP-based with authentication token management
- **Strategy:** Likely uses HTTP mocking libraries

### **train-aws (Cloud Platform) - Coverage Unknown**
**Status:** ✅ **Official InSpec plugin**
- **Type:** AWS API integration for cloud infrastructure
- **Expected Coverage:** 85-95% based on SDK architecture
- **Architecture:** AWS SDK-based with IAM credential handling
- **Strategy:** Likely uses VCR or similar for API mocking

### **train-docker (Container Platform) - Coverage Unknown**
**Status:** ✅ **Built-in core transport**
- **Type:** Docker container execution platform
- **Expected Coverage:** 80-90% based on API + system call mix
- **Architecture:** Docker API integration with container runtime
- **Strategy:** Likely mocks Docker daemon communication

**Note:** Coverage percentages are estimates based on architectural analysis except for train-juniper, which has measured production coverage. Actual coverage may vary based on implementation quality and testing strategies.

## Conclusion

The Train plugin ecosystem demonstrates that **plugin category determines achievable coverage**. Success comes from understanding your category's constraints and designing accordingly.

**Universal Principles:**
1. **Know your category's realistic ceiling** - don't chase impossible targets
2. **Mock-first design** maximizes testable code percentage  
3. **Business logic should be 100% covered** regardless of category
4. **Infrastructure dependencies are expected gaps** - document them
5. **Coverage drives design quality** - use it to find architectural issues

**Category-Specific Takeaways:**
- **API plugins:** Mock HTTP, test business logic (target 85-95%)
- **SSH/Local plugins:** Mock commands, test parsing (target 90-95%)  
- **Network plugins:** Comprehensive mock mode (target 75-85%)
- **Container plugins:** Mock runtimes, test orchestration (target 80-90%)
- **Database plugins:** Mock connections, test SQL logic (target 85-95%)
- **Protocol plugins:** Mock boundaries, test formatting (target 70-85%)

This ecosystem-wide approach ensures realistic expectations, appropriate testing strategies, and production-ready plugins across all Train plugin categories.
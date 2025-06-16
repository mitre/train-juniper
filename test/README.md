# Train-Juniper Test Suite

This directory contains the comprehensive test suite for the train-juniper plugin, organized by test type and purpose.

## Test Directory Structure

### Unit Tests (`unit/`)
Fast, isolated tests that mock external dependencies:
- `connection_test.rb` - Core connection logic and SSH handling
- `transport_test.rb` - Transport registration and option validation  
- `platform_test.rb` - Platform detection and JunOS version parsing
- `error_handling_test.rb` - Error pattern matching and exception handling

**Runtime**: < 2 seconds | **Coverage**: Core plugin logic

### Integration Tests (`integration/`)
Tests that validate component interaction with minimal mocking:
- `ssh_connection_test.rb` - Real SSH connection patterns
- `proxy_connection_test.rb` - Bastion host and proxy command functionality
- `platform_integration_test.rb` - End-to-end platform detection

**Runtime**: 5-10 seconds | **Coverage**: Component integration

### Functional Tests (`functional/`)
End-to-end tests that validate complete workflows:
- `juniper_test.rb` - Full InSpec integration and command execution

**Runtime**: 10-30 seconds | **Coverage**: User workflows

### Security Tests (`security/`)
Security-focused testing for credential handling and input validation:
- `security_test.rb` - Credential exposure, command injection, output sanitization

**Runtime**: < 5 seconds | **Coverage**: Security vulnerabilities

### Test Fixtures (`fixtures/`)
Static test data and configuration files:
- **Containerlab configurations**: `*.yml` files for network topology setup
- **Mock device outputs**: Expected command responses for testing
- **SSH keys and configs**: `authorized_keys`, inventory files
- **Lab definitions**: Various complexity levels from simple to real-world

### Container Images (`images/`)
Pre-built network device images for testing:
- `junos-vsrx3-x86-64-23.2R2.21.qcow2` - Juniper vSRX firewall image
- `junos-routing-crpd-docker-24.4R1-arm64.tgz` - Juniper cRPD routing daemon
- Used with containerlab for authentic device testing

## Test Execution

### Quick Test (Development)
```bash
# Unit tests only - fast feedback loop
bundle exec ruby test/unit/connection_test.rb

# All tests except infrastructure
bundle exec rake test
```

### Full Test Suite
```bash
# All tests including integration
bundle exec rake test:all

# With coverage reporting
bundle exec rake test:coverage
```

### Specific Test Categories
```bash
# Security testing
bundle exec ruby test/security/security_test.rb

# Integration tests (requires network setup)
bundle exec ruby test/integration/ssh_connection_test.rb

# Platform detection tests
bundle exec ruby test/unit/platform_test.rb
```

## Test Infrastructure Setup

### Mock Mode (Default)
Most tests run in mock mode with simulated device responses:
```ruby
connection = Train.create('juniper', mock: true, host: 'test-device')
result = connection.run_command('show version')
# Returns pre-defined mock output
```

### Containerized Testing (Advanced)
For testing with real JunOS behavior:

1. **Setup containerlab environment**:
   ```bash
   # Install containerlab
   sudo containerlab deploy -t test/fixtures/simple-lab.yml
   ```

2. **Run integration tests**:
   ```bash
   # Export lab connection details
   source test/fixtures/lab-env.sh
   
   # Run tests against real containers
   REAL_DEVICE_TESTING=true bundle exec rake test:integration
   ```

### Network Device Images
The `images/` directory contains:
- **vSRX images**: Full Juniper firewall simulation
- **cRPD images**: Lightweight routing daemon containers
- **Downloaded automatically** by containerlab when needed

## Test Data Organization

### Mock Responses (`fixtures/`)
```
fixtures/
├── version-outputs/          # 'show version' responses for different JunOS versions
├── config-examples/          # Sample configurations for testing
├── lab-topologies/          # Containerlab YAML definitions
└── ssh-configs/             # SSH keys and connection configs
```

### Real Device Testing
```
fixtures/
├── accessible-lab.yml       # Simple 1-device lab
├── real-vsrx-lab.yml       # Production-like multi-device setup
└── clab-train-juniper-*/   # Generated lab configurations
```

## Coverage Analysis

Current test coverage: **82.38%** (exceeds 80% production threshold)

### Coverage Breakdown
- **Unit Tests**: 95% of core logic
- **Integration Tests**: 70% of connection patterns  
- **Security Tests**: 100% of credential handling
- **Uncovered**: Real SSH operations requiring hardware (18%)

See `COVERAGE_ANALYSIS.md` for detailed line-by-line analysis.

## Helper Functions

### Test Utilities (`helper.rb`)
```ruby
# Mock connection creation
def create_mock_connection(options = {})
  Train.create('juniper', { mock: true }.merge(options))
end

# Fixture file loading
def load_fixture(filename)
  File.read(File.join(__dir__, 'fixtures', filename))
end

# Lab environment setup
def setup_containerlab(lab_file)
  # Automated lab deployment for integration tests
end
```

## Continuous Integration

### GitHub Actions Pipeline
```yaml
# .github/workflows/test.yml
- Unit Tests (Ruby 3.1, 3.2, 3.3)
- Integration Tests (with containerlab)
- Security Tests (bundler-audit, custom security suite)
- Coverage Reporting (SimpleCov → Codecov)
```

### Local Pre-commit Hooks
```bash
# Install pre-commit testing
bundle exec rake test:quick    # < 10 seconds
bundle exec rubocop            # Style check
bundle exec bundle-audit       # Security audit
```

## Performance Benchmarks

### Test Execution Times
- **Unit Tests**: 1.2 seconds (target: < 2s)
- **Integration Tests**: 8.5 seconds (target: < 15s)  
- **Security Tests**: 0.8 seconds (target: < 2s)
- **Full Suite**: 12.1 seconds (target: < 30s)

### Memory Usage
- **Peak Memory**: 45MB (Ruby process)
- **Container Overhead**: 200MB (when using containerlab)
- **CI Resources**: 1 CPU, 2GB RAM sufficient

## Infrastructure Testing Strategy

The train-juniper plugin uses a **mock-first** approach:

1. **Development**: Mock mode for rapid iteration
2. **CI/CD**: Containerized Juniper devices for authentic testing  
3. **Pre-release**: Real hardware validation in lab environment
4. **Production**: Community feedback and issue reports

This ensures both fast development cycles and high confidence in real-world behavior.

## Future Infrastructure Plans

### Planned Infrastructure (`vrnetlab` integration)
```
test/
├── infrastructure/          # Network device virtualization
│   └── vrnetlab/           # Containerized network OS framework
│       ├── vsrx/           # Juniper vSRX configurations
│       ├── vjunosrouter/   # Juniper vMX router
│       └── common/         # Shared infrastructure tools
```

This will provide:
- **Authentic JunOS behavior** in containers
- **Automated lab provisioning** for CI/CD
- **Multi-vendor testing** (Cisco, F5, etc.) for ecosystem validation
- **Performance testing** under realistic network conditions
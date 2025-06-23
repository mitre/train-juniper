# Test Organization

## Current Test Structure

Our tests are organized by functionality rather than by module/class:

```
test/
├── unit/                    # Unit tests for individual components
│   ├── connection_test.rb   # Connection class and included modules
│   ├── error_handling_test.rb # Error detection and handling
│   ├── juniper_file_test.rb # File abstraction
│   ├── platform_test.rb     # Platform detection
│   └── transport_test.rb    # Transport plugin interface
├── integration/             # Integration tests
│   ├── platform_integration_test.rb # Platform detection integration
│   ├── proxy_connection_test.rb     # Bastion/proxy functionality
│   └── ssh_connection_test.rb       # SSH connection scenarios
├── functional/              # End-to-end functional tests
│   └── juniper_test.rb      # Complete plugin functionality
└── security/                # Security-specific tests
    └── security_test.rb     # Input validation, sanitization

## Testing Strategy

### Why No Separate Module Tests?

After refactoring into modules (Phase 1-3), we kept the existing test structure because:

1. **Modules are Mixed Into Connection**: All module methods become part of the Connection class
2. **Functional Grouping**: Tests are grouped by functionality, not implementation
3. **Integration Testing**: Most valuable tests verify the integrated behavior
4. **Coverage**: Current structure provides 79.19% coverage

### Module Testing Approach

Modules are tested through the Connection class:
- **CommandExecutor**: Tested via connection_test.rb and security_test.rb
- **ErrorHandling**: Tested via error_handling_test.rb
- **SSHSession**: Tested via ssh_connection_test.rb
- **BastionProxy**: Tested via proxy_connection_test.rb
- **Validation**: Tested via connection_test.rb
- **Environment**: Tested implicitly through option handling

### Adding Module-Specific Tests

If you need to add module-specific tests:

1. Create `test/unit/modules/` directory
2. Add test files like `command_executor_test.rb`
3. Test modules in isolation by including them in a test class:

```ruby
class TestCommandExecutor
  include TrainPlugins::Juniper::CommandExecutor
  attr_reader :options, :logger
  
  def initialize
    @options = {}
    @logger = Logger.new(nil)
  end
end
```

## Test Coverage Goals

- **Current**: 79.19% (293/370 lines)
- **Target**: 80%+ for production
- **Focus Areas**: Edge cases, error conditions, security

## Running Tests

```bash
# All tests
bundle exec rake test

# Specific test file
bundle exec ruby -Ilib:test test/unit/connection_test.rb

# With coverage
bundle exec rake test
open coverage/index.html
```
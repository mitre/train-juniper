# Connection Refactor Analysis

## Current State
- `connection.rb`: 583 lines, 36+ methods
- Single file handling all connection logic, validation, SSH, bastion, mocking, and file operations

## Proposed Module Structure

### 1. `lib/train-juniper/connection.rb` (Main orchestrator, ~100 lines)
- Initialize connection
- Delegate to appropriate modules
- Basic connection state management
- Public API methods (run_command, file, etc.)

### 2. `lib/train-juniper/ssh_session.rb` (~150 lines)
- SSH connection establishment
- SSH options building
- Session management
- Connection health checks

### 3. `lib/train-juniper/bastion_proxy.rb` (~100 lines)
- Bastion/proxy configuration
- SSH_ASKPASS script creation
- Proxy jump setup
- Bastion-specific error handling

### 4. `lib/train-juniper/command_executor.rb` (~100 lines)
- Command sanitization
- Command execution
- Result formatting
- JunOS error detection
- Output cleaning

### 5. `lib/train-juniper/validation.rb` (~80 lines)
- All validation methods
- Required options validation
- Type validation
- Port/timeout validation

### 6. `lib/train-juniper/environment_helpers.rb` (~30 lines)
- env_value method
- env_int method
- Other environment utilities

### 7. `lib/train-juniper/juniper_file.rb` (~50 lines)
- Move JuniperFile class to its own file
- File operations

### 8. `lib/train-juniper/mock_responses.rb` (Already exists)
- Enhance with more mock capabilities
- Mock session management

## Benefits

1. **Separation of Concerns**: Each module has a single responsibility
2. **Easier Testing**: Can test each module in isolation
3. **Better Maintainability**: Smaller files are easier to understand
4. **Reusability**: Modules can be reused or extended independently
5. **Team Collaboration**: Multiple developers can work on different modules
6. **Performance**: Can lazy-load modules only when needed

## Implementation Strategy

1. Start with easiest extractions (JuniperFile, Validation)
2. Extract environment helpers
3. Extract command execution logic
4. Extract bastion/proxy support
5. Extract SSH session management
6. Refactor main connection class to delegate

## Example Refactored Connection Class

```ruby
module TrainPlugins
  module Juniper
    class Connection < Train::Plugins::Transport::BaseConnection
      include EnvironmentHelpers
      include Validation
      
      def initialize(options)
        @options = options
        @logger = options[:logger] || Logger.new($stdout)
        validate_connection_options!
        
        @ssh_session_manager = SSHSession.new(@options, @logger)
        @command_executor = CommandExecutor.new(@options, @logger)
        @bastion_proxy = BastionProxy.new(@options, @logger) if @options[:bastion_host]
      end
      
      def run_command_via_connection(cmd)
        return MockResponses.execute(cmd) if @options[:mock]
        
        connect unless connected?
        @command_executor.execute(@ssh_session, cmd)
      end
      
      def connect
        return if connected?
        
        ssh_options = @ssh_session_manager.build_options
        @bastion_proxy&.configure(ssh_options)
        
        @ssh_session = @ssh_session_manager.connect(ssh_options)
      end
      
      # ... other delegated methods
    end
  end
end
```

## Questions to Consider

1. Should we use modules (mixins) or separate classes?
2. How much should we refactor in one go vs. incremental?
3. Should mock functionality be a separate connection type?
4. Do we need a facade pattern for backward compatibility?

## Refactoring Task Matrix

| Phase | Module | Status | Lines | Location | Notes |
|-------|--------|--------|-------|----------|-------|
| **Phase 1** | | | | | |
| 1 | JuniperFile | ✅ Complete | 67 | `file_abstraction/juniper_file.rb` | Extracted nested class |
| 1 | Environment | ✅ Complete | 32 | `helpers/environment.rb` | env_value, env_int methods |
| 1 | Validation | ✅ Complete | 54 | `connection/validation.rb` | All 7 validation methods |
| **Phase 2** | | | | | |
| 2 | CommandExecutor | ✅ Complete | 95 | `connection/command_executor.rb` | run_command, sanitize, format |
| 2 | ErrorHandling | ✅ Complete | 71 | `connection/error_handling.rb` | Error patterns and messages |
| **Phase 3** | | | | | |
| 3 | SSHSession | ✅ Complete | 101 | `connection/ssh_session.rb` | Connection management |
| 3 | BastionProxy | ✅ Complete | 90 | `connection/bastion_proxy.rb` | Bastion/proxy support |
| **Phase 4** | | | | | |
| 4 | Test Reorganization | ⏳ Pending | N/A | `test/` | Match new modular structure |

### Progress Summary
- **Original**: 583 lines in connection.rb
- **Phase 1**: 480 lines (103 lines extracted, 18% reduction)
- **Phase 2**: 364 lines (116 lines extracted, 24% reduction)
- **Phase 3**: 214 lines (150 lines extracted, 41% reduction)
- **Cumulative**: 369 lines extracted (63% reduction)
- **Target Achieved**: 214 lines (below 250 line target)

## Next Steps

1. ✅ Execute Phase 1 refactoring
2. Consider directory structure reorganization
3. Execute Phase 2 refactoring
4. Update tests as needed
5. Document the new architecture
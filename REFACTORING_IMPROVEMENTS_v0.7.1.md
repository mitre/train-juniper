# Refactoring Improvements for v0.7.1

## Priority 1: Quick Wins (Do these for v0.7.1)

### 1. Extract Port Validation
Create a DRY method in validation.rb:
```ruby
def validate_port_value!(port_key, port_name = port_key.to_s)
  port = @options[port_key].to_i
  raise Train::ClientError, "Invalid #{port_name}: #{@options[port_key]} (must be 1-65535)" unless port.between?(1, 65_535)
end

def validate_port!
  validate_port_value!(:port)
end

def validate_bastion_port!
  validate_port_value!(:bastion_port)
end
```

### 2. Extract Common Constants
Create `lib/train-juniper/constants.rb`:
```ruby
module TrainPlugins
  module Juniper
    module Constants
      # SSH Configuration
      DEFAULT_SSH_PORT = 22
      PORT_RANGE = (1..65_535).freeze
      
      # SSH Options
      STANDARD_SSH_OPTIONS = {
        'UserKnownHostsFile' => '/dev/null',
        'StrictHostKeyChecking' => 'no',
        'LogLevel' => 'ERROR',
        'ForwardAgent' => 'no'
      }.freeze
      
      # JunOS Patterns
      CLI_PROMPT = /[%>$#]\s*$/
      CONFIG_PROMPT = /[%#]\s*$/
      
      # File Paths
      CONFIG_PATH_PATTERN = %r{/config/(.*)}.freeze
      OPERATIONAL_PATH_PATTERN = %r{/operational/(.*)}.freeze
    end
  end
end
```

### 3. Remove Duplicate Requires
- Remove `require 'train'` from modules since connection.rb already requires it
- Move all requires to the top of connection.rb in a logical order

## Priority 2: Nice to Have (Consider for v0.7.2)

### 4. Command Result Factory
Add to command_executor.rb:
```ruby
private

def success_result(output, cmd = nil)
  output = clean_output(output, cmd) if cmd
  Train::Extras::CommandResult.new(output, '', 0)
end

def error_result(message)
  Train::Extras::CommandResult.new('', message, 1)
end
```

### 5. Consolidate Error Messages
Create error message templates module

### 6. Logging Helpers
Create consistent logging patterns

## What We're NOT Changing

1. **ENV_CONFIG Pattern** - It's already well-structured
2. **Module Organization** - Current structure is clean and logical
3. **Test Structure** - Works well as-is
4. **Platform Detection** - Already optimized

## Implementation Order

1. Create constants.rb with common constants
2. Update validation.rb to DRY port validation
3. Update modules to use constants
4. Remove redundant requires
5. Test everything still works
6. Update version to 0.7.1

## Benefits

- Reduces code duplication by ~30-40 lines
- Makes future port/SSH option changes easier
- Improves consistency across modules
- Maintains backward compatibility
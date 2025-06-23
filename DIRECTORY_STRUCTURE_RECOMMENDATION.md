# Directory Structure Recommendation

## Current Structure (Flat)
```
lib/train-juniper/
├── connection.rb          # Main connection class (480 lines)
├── environment_helpers.rb # Helper module (32 lines)
├── juniper_file.rb       # File abstraction (67 lines)
├── mock_responses.rb     # Mock data (57 lines)
├── platform.rb           # Platform detection (170 lines)
├── transport.rb          # Transport definition (67 lines)
├── validation.rb         # Validation module (54 lines)
└── version.rb            # Version constant (13 lines)
```

## Option 1: Group by Functionality (Recommended)
```
lib/train-juniper/
├── connection.rb         # Main connection orchestrator
├── platform.rb          # Platform detection (keep at root)
├── transport.rb         # Transport definition (keep at root)
├── version.rb           # Version constant (keep at root)
├── connection/          # Connection-related modules
│   ├── bastion_proxy.rb      # Phase 3: Bastion/proxy support
│   ├── command_executor.rb   # Phase 2: Command execution
│   ├── error_handling.rb     # Phase 2: Error patterns
│   ├── ssh_session.rb        # Phase 3: SSH management
│   └── validation.rb         # Validation methods (move)
├── helpers/             # Utility modules
│   ├── environment.rb        # Environment helpers (rename)
│   └── mock_responses.rb     # Mock data (move)
└── file_abstraction/    # File operations
    └── juniper_file.rb       # JuniperFile class (move)
```

## Option 2: Minimal Reorganization
```
lib/train-juniper/
├── connection.rb        # Main connection class
├── platform.rb         # Platform detection
├── transport.rb        # Transport definition
├── version.rb          # Version constant
├── helpers/            # All helper modules
│   ├── environment_helpers.rb
│   ├── juniper_file.rb
│   ├── mock_responses.rb
│   └── validation.rb
└── # Future: connection/ for Phase 2&3 modules
```

## Option 3: Keep Flat (Current)
- Pros: Simple, all files visible, easy imports
- Cons: Gets cluttered with more modules
- Works well for up to ~15 files

## Recommendation: Option 1

### Reasons:
1. **Logical Grouping**: Related functionality stays together
2. **Scalability**: Easy to add more modules without clutter
3. **Clear Intent**: Directory names communicate purpose
4. **Standard Pattern**: Common in Ruby gems (see fog, faraday)
5. **Import Paths**: Still relatively simple:
   ```ruby
   require 'train-juniper/connection/validation'
   require 'train-juniper/helpers/environment'
   ```

### Migration Plan:
1. Phase 1 completion: Keep flat for now
2. Before Phase 2: Reorganize existing modules
3. Phase 2 & 3: Add new modules in proper directories

### Import Changes Required:
```ruby
# connection.rb changes:
require 'train-juniper/connection/validation'
require 'train-juniper/helpers/environment'
require 'train-juniper/file_abstraction/juniper_file'
require 'train-juniper/helpers/mock_responses'

# Include statements remain the same:
include TrainPlugins::Juniper::Validation
include TrainPlugins::Juniper::EnvironmentHelpers
```

## Decision Points:
1. When to reorganize? (Now vs. before Phase 2)
2. How deep? (One level vs. nested)
3. Naming conventions? (helpers vs. support vs. core)
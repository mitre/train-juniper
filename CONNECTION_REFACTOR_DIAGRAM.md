# Connection Architecture Diagram

## Current Architecture (Monolithic)
```
connection.rb (583 lines)
├── Connection class
│   ├── Initialization & state
│   ├── SSH connection logic
│   ├── Bastion/proxy support
│   ├── Command execution
│   ├── Result formatting
│   ├── Validation methods
│   ├── Mock support
│   └── Environment helpers
└── JuniperFile class
```

## Proposed Architecture (Modular)
```
lib/train-juniper/
├── connection.rb (Main orchestrator)
│   └── Connection class
│       ├── initialize (setup collaborators)
│       ├── run_command_via_connection (delegate)
│       ├── file_via_connection (delegate)
│       └── connect (orchestrate)
│
├── ssh_session.rb
│   └── SSHSession class
│       ├── build_options
│       ├── connect
│       ├── connected?
│       └── test_and_configure_session
│
├── bastion_proxy.rb
│   └── BastionProxy module
│       ├── configure_proxy
│       ├── setup_password_auth
│       ├── create_ssh_askpass_script
│       └── bastion_error_message
│
├── command_executor.rb
│   └── CommandExecutor class
│       ├── execute
│       ├── sanitize_command
│       ├── format_result
│       └── clean_output
│
├── validation.rb
│   └── Validation module
│       ├── validate_connection_options!
│       ├── validate_required_options!
│       ├── validate_option_types!
│       └── validate_ports_and_timeouts!
│
├── environment_helpers.rb
│   └── EnvironmentHelpers module
│       ├── env_value
│       └── env_int
│
├── juniper_file.rb
│   └── JuniperFile class
│       ├── content
│       ├── exist?
│       └── to_s
│
└── mock_responses.rb (existing)
    └── MockResponses module
        ├── response_for
        └── mock data definitions
```

## Dependency Flow
```
Connection (orchestrator)
    ├─> uses EnvironmentHelpers (mixin)
    ├─> uses Validation (mixin)
    ├─> creates SSHSession
    ├─> creates CommandExecutor
    ├─> creates BastionProxy (optional)
    ├─> creates JuniperFile (on demand)
    └─> uses MockResponses (when mocked)
```

## Key Design Principles

1. **Single Responsibility**: Each module/class has one clear purpose
2. **Dependency Injection**: Connection class creates and injects dependencies
3. **Interface Segregation**: Modules expose minimal, focused interfaces
4. **Open/Closed**: Easy to extend without modifying existing code
5. **Testability**: Each component can be tested in isolation
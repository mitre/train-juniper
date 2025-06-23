# API Documentation

The train-juniper plugin provides a comprehensive API for connecting to and interacting with Juniper Networks devices running JunOS.

## Accessing the API Documentation

The full API documentation is generated using YARD and provides detailed information about:

- Classes and modules
- Method signatures and parameters
- Return values and exceptions
- Usage examples
- Configuration options

!!! info "API Documentation Access"
    The full YARD API documentation is generated during the build process and will be available at:
    
    - **Local Development**: Run `bundle exec yard server` to view at [http://localhost:8808](http://localhost:8808)
    - **GitHub Pages**: Available at [https://mitre.github.io/train-juniper/api/](https://mitre.github.io/train-juniper/api/) after deployment  
    - **RubyDoc.info**: Automatically published at [https://rubydoc.info/gems/train-juniper](https://rubydoc.info/gems/train-juniper) after gem release

## Key Classes

### TrainPlugins::Juniper::Transport
The main transport class that registers the plugin with Train and defines connection options.

### TrainPlugins::Juniper::Connection
Handles SSH connections to Juniper devices, command execution, and platform detection.

### TrainPlugins::Juniper::Platform
Provides platform detection capabilities for identifying JunOS versions and architectures.

## Quick Reference

### Creating a Connection

```ruby
require 'train'

conn = Train.create('juniper',
  host: '192.168.1.1',
  user: 'admin',
  password: 'secret'
)
```

### Running Commands

```ruby
result = conn.run_command('show version')
puts result.stdout
puts result.exit_status
```

### Using with InSpec

```ruby
describe juniper_command('show interfaces terse') do
  its('stdout') { should match /ge-0\/0\/0.*up/ }
end
```

For complete API details, method signatures, and advanced usage, please refer to the [full API documentation](/train-juniper/api/).
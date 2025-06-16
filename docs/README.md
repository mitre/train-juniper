# train-juniper Documentation

This directory contains comprehensive documentation for the train-juniper plugin development and usage.

## Documentation Structure

### Development
- **[development-environment.md](development-environment.md)** - Complete setup guide for containerlab + vrnetlab testing
- **[testing-strategy.md](../TRAIN_JUNIPER_IMPLEMENTATION_PLAN.md#testing-strategy)** - Testing approaches and CI/CD integration

### Research & Planning  
- **[implementation-plan.md](../TRAIN_JUNIPER_IMPLEMENTATION_PLAN.md)** - Comprehensive implementation roadmap
- **[research-summary.md](../TRAIN_JUNIPER_RESEARCH_SUMMARY.md)** - Detailed research findings and architecture analysis

### Quick Start

1. **Setup Development Environment**
   ```bash
   # macOS: Use containerlab in Linux VM
   # See development-environment.md for details
   ```

2. **Deploy Test Lab**
   ```bash
   sudo containerlab deploy -t test/fixtures/vsrx-lab.yml
   ```

3. **Test Plugin**
   ```bash
   bundle exec ruby test_connection.rb
   ```

### Key Technologies

- **containerlab**: Lab orchestration ("Lab-as-Code")
- **vrnetlab**: VM-to-container packaging for network OS
- **Docker**: Container runtime (managed by containerlab)
- **net-ssh-telnet**: SSH prompt handling for JunOS devices

### Connection Details

```ruby
# Standard vSRX connection via containerlab
{
  host: '172.20.20.2',     # containerlab management IP
  user: 'admin',
  password: 'admin@123',
  port: 22
}
```

## External References

- [containerlab documentation](https://containerlab.dev/)
- [vrnetlab repository](https://github.com/hellt/vrnetlab)
- [Train plugin architecture](https://github.com/inspec/train/blob/main/docs/plugins.md)
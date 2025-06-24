# Quick Start Installation

Get up and running with Train-Juniper in minutes!

!!! tip "Platform-Specific Setup"
    === "macOS/Linux"
        You're ready to go! Just ensure Ruby 3.0+ is installed.
        
    === "Windows"
        - **Ruby Setup**: See [Windows Ruby Setup](windows-setup.md) for development environment
        - **Bastion/Jump Hosts**: See [Windows Bastion Setup](windows-bastion-setup.md) for authentication options

## Prerequisites

### Ruby Environment
- **Ruby**: 3.0+ (3.1.6+ recommended)
- **Bundler**: Latest version
- **InSpec**: 6.0+ (latest recommended)

### System Requirements
- **SSH Client**: OpenSSH or compatible
- **Network Access**: Connectivity to target Juniper devices
- **Platform**: Linux, macOS, or Windows

## Installation Methods

### Method 1: From RubyGems :material-star:{ .mdx-pulse } { .annotate }

1. **Recommended for most users**

```bash
# Install by name from RubyGems (once published)
inspec plugin install train-juniper

# Verify installation
inspec plugin list
```

!!! success "Installation Complete"
    If you see `train-juniper` in the plugin list, you're ready to go!

[Get Started with Basic Usage](basic-usage.md){ .md-button .md-button--primary }

### Method 2: Local Gem Installation :material-developer-board:

!!! warning "Development Installation"
    This method is for development and testing. Use Method 1 for production.

=== "Quick Steps"
    ```bash
    git clone https://github.com/mitre/train-juniper.git
    cd train-juniper
    bundle install
    gem build train-juniper.gemspec
    inspec plugin install ./train-juniper-0.4.0.gem
    ```

=== "Detailed Steps"
    1. **Clone repository**
       ```bash
       git clone https://github.com/mitre/train-juniper.git
       cd train-juniper
       ```

    2. **Install dependencies**
       ```bash
       bundle install
       ```

    3. **Build gem file**
       ```bash
       gem build train-juniper.gemspec
       ```

    4. **Install local gem**
       ```bash
       inspec plugin install ./train-juniper-0.4.0.gem
       ```

### Method 3: Bundle Development (Developers)

```bash
# Clone repository
git clone https://github.com/mitre/train-juniper.git
cd train-juniper

# Install dependencies
bundle install

# Use with bundle exec
bundle exec inspec shell -t juniper://device.example.com
```

## Verification

### Test Plugin Loading

```bash
# Verify plugin is registered
inspec plugin list
# Should show: train-juniper

# Test URI scheme recognition
inspec shell -t juniper://
# Should show usage help, not "unsupported scheme"
```

### Test Mock Connection

```bash
# Test with mock mode
inspec shell -t juniper://mock --reporter json
```

Expected output:
```json
{
  "platform": {
    "name": "juniper",
    "families": ["bsd", "unix", "os"],
    "release": "0.4.0"
  }
}
```

### Test Real Device Connection

```bash
# Test with real device (replace with your device)
inspec shell -t juniper://admin@device.example.com
```

Expected output:
```
You are currently running on:
    Name:      juniper
    Families:  bsd, unix, os
    Release:   23.4R1.9
    Arch:      amd64
```

## Configuration

### SSH Configuration

The plugin respects standard SSH configuration:

**~/.ssh/config**:
```
Host *.juniper.lab
  User admin
  Port 2222
  IdentityFile ~/.ssh/juniper_key
  StrictHostKeyChecking no

Host jump.example.com
  User admin
  IdentityFile ~/.ssh/bastion_key
```

### Environment Variables

Set these for convenience:

```bash
# Device credentials
export JUNIPER_HOST=device.example.com
export JUNIPER_USER=admin
export JUNIPER_PASSWORD=secret123

# Bastion configuration
export JUNIPER_BASTION_HOST=jump.example.com
export JUNIPER_BASTION_USER=admin

# Connection tuning
export JUNIPER_TIMEOUT=60
export JUNIPER_PORT=22
```

## Troubleshooting Installation

!!! bug "Common Installation Issues"
    Having trouble? Check these common problems and solutions.

### Plugin Not Found

!!! failure "Error Message"
    ```
    Can't find train plugin juniper
    ```

**Solutions**:

=== "Check Installation"
    ```bash
    # Verify plugin is installed
    inspec plugin list
    ```

=== "Reinstall Plugin"
    ```bash
    # Remove and reinstall
    inspec plugin uninstall train-juniper
    inspec plugin install train-juniper
    ```

=== "Windows Alternative"
    ```powershell
    # If InSpec plugin install fails on Windows
    # Use direct gem installation instead:
    gem install train-juniper
    
    # Then verify it works:
    inspec shell -t juniper://mock
    ```

=== "Check Gem Environment"
    ```bash
    # Verify gem is available
    gem list train-juniper
    ```

### InSpec Plugin Manager Issues

**Error**: `Plugin failed to load`

**Debug Steps**:
```bash
# Test gem loads in Ruby
ruby -e "require 'train-juniper'; puts 'OK'"

# Check InSpec gem compatibility
inspec version
ruby --version

# Clean plugin cache
rm -rf ~/.inspec/plugins/
inspec plugin install train-juniper
```

### Dependency Conflicts

**Error**: `Gem::ConflictError`

**Solution**: Use bundle development mode:
```bash
git clone https://github.com/mitre/train-juniper.git
cd train-juniper
bundle install
bundle exec inspec shell -t juniper://device.example.com
```

### SSH Connection Issues

**Error**: `SSH authentication failed`

**Debug Steps**:
```bash
# Test SSH manually
ssh admin@device.example.com

# Enable SSH debug in plugin
TRAIN_DEBUG=true inspec shell -t juniper://admin@device.example.com

# Check SSH agent
ssh-add -l
```

## Development Setup

For plugin development and contribution:

### 1. Clone and Setup

```bash
git clone https://github.com/mitre/train-juniper.git
cd train-juniper
bundle install
```

### 2. Run Tests

```bash
# All tests
bundle exec rake test

# Unit tests only
bundle exec ruby -Ilib:test test/unit/transport_test.rb

# Code coverage
bundle exec rake test
open coverage/index.html
```

### 3. Code Quality

```bash
# Linting
bundle exec rubocop

# Security audit
bundle exec bundle-audit check
```

### 4. Local Testing

```bash
# Build and test gem
gem build train-juniper.gemspec
inspec plugin install train-juniper-0.4.0.gem

# Test with real device
inspec shell -t juniper://admin@your-device.com
```

## Next Steps

- **[Basic Usage](basic-usage.md)** - Learn to use the plugin
- **[Train Plugin Development Guide](https://github.com/mitre/train-plugin-development-guide)** - Comprehensive development documentation
- **[Contributing Guide](CONTRIBUTING.md)** - How to contribute to the project

## Support

- **Issues**: [GitHub Issues](https://github.com/mitre/train-juniper/issues)
- **Development**: [Contributing Guide](CONTRIBUTING.md)
- **Security**: [Security Policy](SECURITY.md)
# Train-Juniper Plugin Roadmap

Future development plans and improvement roadmap for the train-juniper plugin.

## Current Status: v0.6.2 - Production Ready

Production-ready plugin with comprehensive testing, security infrastructure, and automated release process.

## Recently Completed (v0.6.x)

- ✅ **Windows compatibility** - Fixed FFI dependency for Windows users
- ✅ **Mock mode improvements** - Accurate platform detection in mock mode
- ✅ **Trusted publishing** - OIDC authentication for gem releases
- ✅ **Automated release process** - git-cliff changelog generation
- ✅ **Ruby 3.3 support** - Updated workflows for latest Ruby
- ✅ **Comprehensive documentation** - Installation, usage, and troubleshooting guides

## Possible Future Enhancements

### JunOS-Specific Features

#### NETCONF Transport Option
- Alternative connection method using NETCONF protocol (port 830)
- Leverage `net-netconf` gem for protocol handling
- Would allow: `inspec detect -t juniper-netconf://device:830`
- Returns structured XML responses instead of CLI text
- Better for automation-heavy use cases

#### Enhanced Command Support
- Support for configuration mode commands (enter configure mode, make changes)
- Commit/rollback operations support (if needed for InSpec resources)
- Better handling of command errors and warnings

### Connection Improvements

#### Connection Reliability
- Automatic reconnection on connection drops
- Connection pooling for InSpec profiles with many resources (reuse SSH connection across multiple resources)

### Developer Experience

#### Enhanced Mock Mode
- Expand mock responses for more JunOS commands (currently supports show version, show interfaces, show configuration, etc.)
- Support for custom mock data files (user-provided responses)
- Mock mode for different JunOS versions/platforms (MX, EX, QFX series)

#### Debugging Tools
- Enhanced debug logging options
- Connection troubleshooting commands
- Performance profiling for slow commands

### InSpec Resource Support

#### Example Resources
- Create example InSpec resources for common JunOS checks
- Resource pack for Juniper compliance
- Documentation for writing custom Juniper resources

### Community Contributions

We welcome contributions! Priority areas include:
- Additional platform detection patterns for newer JunOS versions
- Mock data for different Juniper device types (MX, EX, QFX)
- Bug fixes and performance improvements
- Documentation improvements

## Contributing

Interested in contributing to these features? See our [Contributing Guide](CONTRIBUTING.md) for:

- Development setup instructions
- Coding standards and patterns
- Testing requirements
- Pull request process

## Feedback

Have ideas for new features or improvements? Please:

- Open a [GitHub Issue](https://github.com/mitre/train-juniper/issues) for feature requests
- Join discussions in existing issues
- Contact the team at [saf@mitre.org](mailto:saf@mitre.org)

---

*This roadmap is subject to change based on community feedback, security requirements, and emerging JunOS features.*
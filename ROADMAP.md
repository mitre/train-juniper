---
title: Development Roadmap
description: Future plans and completed milestones for train-juniper
---

# Train-Juniper Plugin Roadmap

## :material-rocket-launch: Current Status: v0.7.4

!!! success "Production Ready"
    Train-juniper is production-ready with **100% code coverage**, comprehensive security testing, and enterprise-grade architecture.

<div class="grid cards" markdown>

- :material-check-all: __Code Quality__

    ---

    - **100% test coverage** achieved
    - Zero RuboCop violations
    - Comprehensive security testing
    - Modern Ruby patterns

- :material-shield-check: __Security First__

    ---

    - Command injection protection
    - Credential sanitization
    - Security test suite
    - Regular dependency audits

- :material-package-variant: __Enterprise Ready__

    ---

    - Bastion proxy support
    - Environment configuration
    - Comprehensive logging
    - Mock mode for CI/CD

</div>

## :material-history: Recently Completed

### v0.7.x Series - Architecture Excellence
- ✅ **Modular architecture** - Complete refactoring into focused modules
- ✅ **100% test coverage** - Achieved perfect coverage with SimpleCov
- ✅ **DRY improvements** - Factory methods and logging helpers
- ✅ **Security hardening** - Command sanitization and credential protection
- ✅ **Material for MkDocs** - Beautiful documentation with coverage reports
- ✅ **Windows bastion support** - plink.exe integration for password authentication
- ✅ **Cross-platform compatibility** - Full support for Linux, macOS, and Windows
- ✅ **Enhanced error handling** - Command context in error messages

### v0.6.x Series - Production Readiness  
- ✅ **Windows compatibility** - Fixed FFI dependency for Windows users
- ✅ **Mock mode improvements** - Accurate platform detection in mock mode
- ✅ **Trusted publishing** - OIDC authentication for gem releases
- ✅ **Automated release process** - git-cliff changelog generation
- ✅ **Ruby 3.3 support** - Updated workflows for latest Ruby

## :material-target: Prioritization Strategy

!!! summary "Focus Areas"
    Based on user feedback and STIG compliance requirements, we're focusing on:
    
    1. **Complete the InSpec Resource Pack** - Already 52% done, critical for STIG compliance
    2. **Enhanced Mock Mode** - Essential for testing resources without devices
    3. **Configuration Mode** - Required for several STIG controls
    4. **Better Debugging** - Helps users troubleshoot connection issues
    
    Features in "Wait for Demand" are valuable but should be driven by specific user needs.

!!! info "Estimated Timeline"
    - **Q3 2025**: Complete InSpec Resource Pack v1.0
    - **Q3 2025**: Enhanced mock mode with device profiles
    - **Q4 2025**: Configuration mode support
    - **Q4 2025**: Advanced debugging features

## :material-road: Future Enhancements

### :material-target: High Priority - Should Target

!!! important "These features provide immediate value and have clear use cases"

#### :material-library: InSpec Resource Pack (In Progress)

!!! success "Already 52% Complete"
    The InSpec resource pack is actively being developed to support STIG compliance:
    
    **Core Resources (Ready for testing):**
    - ✅ `juniper_system_alarms` - System alarm monitoring
    - ✅ `juniper_system_boot_messages` - Boot message analysis
    - ✅ `juniper_system_core_dumps` - Core dump detection
    - ✅ `juniper_system_ntp` - NTP configuration validation
    - ✅ `juniper_system_services` - Service state verification
    - ✅ `juniper_system_storage` - Storage utilization checks
    - ✅ `juniper_system_uptime` - System uptime tracking
    - ✅ `juniper_system_users` - User account auditing
    
    **Priority Resources (Next targets):**
    - `juniper_security_policies` - Firewall policy validation
    - `juniper_interfaces` - Interface configuration checks
    - `juniper_routing_options` - Routing security validation
    - `juniper_snmp` - SNMP configuration auditing

#### :material-test-tube: Enhanced Mock Mode

- **Custom mock data loading** from YAML/JSON files
- **Device-specific mocks** (MX240, EX4300, QFX5100, vSRX)
- **Scenario-based mocking** for different compliance states
- **Mock data validation** against real device schemas

#### :material-cog: Configuration Mode Support

!!! info "Required for STIG compliance"
    Several STIG controls require configuration verification:
    
    ```ruby
    # Example use case
    describe juniper_configuration do
      its('system login message') { should match /DoD Notice and Consent Banner/ }
      its('protocols ospf') { should_not be_configured }
    end
    ```

#### :material-bug: Enhanced Debugging & Diagnostics

- **Connection diagnostics** command for troubleshooting
- **Command history** tracking for debugging
- **Performance metrics** for slow commands
- **Verbose error messages** with suggested fixes

### :material-clock: Lower Priority - Wait for Demand

!!! info "These features are valuable but should wait for user requests"

#### :material-network: Advanced Connectivity

!!! info "NETCONF Transport"
    Add NETCONF protocol support as an alternative to SSH
    
    ```bash
    inspec detect -t juniper-netconf://device:830
    ```
    
    - Structured XML responses
    - Better for automation
    - Uses `net-netconf` gem
    - Industry-standard protocol

!!! example "Connection Resilience"
    - Automatic reconnection on drops
    - Connection pooling for profiles
    - Persistent session management
    - Health check mechanisms

### :material-code-braces: JunOS Capabilities

=== "Configuration Mode"
    - Enter configuration mode
    - Make configuration changes
    - Commit/rollback support
    - Candidate configuration

=== "Advanced Commands"
    - Operational mode extensions
    - Custom RPC calls
    - Error handling improvements
    - Multi-line output parsing

#### :material-speedometer: Performance & Profiling

- Performance profiling tools
- Command timing metrics
- Connection pooling for multiple devices
- Batch command execution

#### :material-puzzle: Protocol & Feature Extensions

| Feature | Description | Rationale |
|---------|-------------|-----------|
| BGP Support | Validate BGP configurations | Wait for specific use case |
| OSPF Support | Check OSPF neighbor states | Wait for specific use case |
| VLAN Validation | Verify VLAN configurations | Wait for specific use case |
| Hardware Info | Chassis and component details | Wait for specific use case |
| Config Diff | Compare running vs candidate | Part of config mode support |
| Custom RPC calls | Direct JunOS RPC execution | Complex implementation |
| Advanced file operations | Upload/download configs | Security implications |

## :material-handshake: How to Contribute

!!! question "Want to help?"
    We welcome contributions in all areas! Here's how to get started:

<div class="grid cards" markdown>

- :material-code-tags: __Code Contributions__

    ---

    - Pick an item from the roadmap
    - Check our [Contributing Guide](CONTRIBUTING.md)
    - Follow our coding standards
    - Submit a pull request

- :material-file-document-edit: __Documentation__

    ---

    - Improve existing docs
    - Add usage examples
    - Create tutorials
    - Fix typos and clarity

- :material-test-tube: __Testing & QA__

    ---

    - Test on different JunOS versions
    - Report bugs and edge cases
    - Contribute mock data
    - Performance testing

- :material-lightbulb: __Ideas & Feedback__

    ---

    - [Open an issue](https://github.com/mitre/train-juniper/issues)
    - Join discussions
    - Share use cases
    - Vote on features

</div>

## :material-email: Contact

<div class="grid cards" markdown>

- :material-github: __GitHub__

    ---

    [github.com/mitre/train-juniper](https://github.com/mitre/train-juniper)

- :material-email-outline: __Email__

    ---

    [saf@mitre.org](mailto:saf@mitre.org)

- :material-slack: __Community__

    ---

    Join our community discussions

</div>

---

!!! info "Living Document"
    This roadmap evolves based on community feedback, security requirements, and emerging JunOS features. Last updated: {{ git_revision_date }}
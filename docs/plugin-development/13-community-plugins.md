# Community Plugins

Comprehensive directory of Train plugins, ecosystem patterns, and community resources for plugin developers.

## Table of Contents

1. [Plugin Directory](#plugin-directory)
2. [Organization Ecosystem](#organization-ecosystem)
3. [Plugin Categories](#plugin-categories)
4. [Quality Assessment](#quality-assessment)
5. [Contributing Guidelines](#contributing-guidelines)
6. [Community Resources](#community-resources)
7. [Plugin Discovery](#plugin-discovery)
8. [Ecosystem Health](#ecosystem-health)

---

## Plugin Directory

### Active Community Plugins

| Plugin | Maintainer | Category | Status | Last Updated |
|--------|------------|----------|--------|--------------|
| **[train-rest](https://github.com/prospectra/train-rest)** | Prospectra | API Transport | ✅ Active | 2023-11 |
| **[train-awsssm](https://github.com/prospectra/train-awsssm)** | Prospectra | Cloud Service | ✅ Active | 2023-10 |
| **[train-telnet](https://github.com/prospectra/train-telnet)** | Prospectra | Network Device | ✅ Active | 2023-09 |
| **[train-juniper](https://github.com/mitre/train-juniper)** | MITRE SAF | Network Device | ✅ Active | 2023-12 |
| **[train-pwsh](https://github.com/mitre/train-pwsh)** | MITRE SAF | Windows Automation | ✅ Active | 2023-11 |
| **[train-k8s-container](https://github.com/inspec/train-k8s-container)** | InSpec Team | Container Platform | ✅ Active | 2023-10 |

### Built-in Transport Plugins (Train Core)

These transports are built directly into the main Train gem and available immediately:

| Plugin | Category | Description | Documentation | Status |
|--------|----------|-------------|---------------|---------|
| **train-ssh** | Remote Access | SSH connectivity for Unix/Linux systems | [Core docs](https://docs.chef.io/inspec/transports/) | ✅ Well documented |
| **train-local** | Local Execution | Local system execution | [Core docs](https://docs.chef.io/inspec/transports/) | ✅ Well documented |
| **train-docker** | Container Platform | Docker container execution | [Core docs](https://docs.chef.io/inspec/transports/) | ✅ Well documented |
| **train-podman** | Container Platform | Podman container execution | [Core docs](https://docs.chef.io/inspec/transports/) | ✅ Well documented |
| **train-azure** | Cloud Platform | Microsoft Azure API integration | [Core docs](https://docs.chef.io/inspec/transports/) | ✅ Well documented |
| **train-gcp** | Cloud Platform | Google Cloud Platform API integration | [Core docs](https://docs.chef.io/inspec/transports/) | ✅ Well documented |
| **train-vmware** | Virtualization | VMware vSphere API integration | [Core docs](https://docs.chef.io/inspec/transports/) | ✅ Well documented |
| **train-cisco-ios** | Network Device | Cisco IOS/IOS-XE network device connectivity | ❌ **Undocumented** | ⚠️ **Hidden gem** |
| **train-mock** | Testing | Mock transport for testing purposes | ❌ **Undocumented** | ⚠️ **Unmaintained** |

**Important Notes**:
- **train-cisco-ios**: Built-in but completely undocumented! Available as `ios://` URI scheme.
- **train-mock**: User-facing but "use with no guarantee" - not well maintained.
- **Documentation gap**: Official docs don't reflect what's actually built into Train core.

### Official InSpec Transport Plugins (Separate Repos)

These transports are maintained by the InSpec team but in separate repositories:

| Plugin | Repository | Category | Status | Last Updated |
|--------|------------|----------|--------|--------------|
| **[train-winrm](https://github.com/inspec/train-winrm)** | inspec/train-winrm | Remote Access | ✅ Active | 3 days ago |
| **[train-aws](https://github.com/inspec/train-aws)** | inspec/train-aws | Cloud Platform | ✅ Active | Jul 2024 |
| **[train-k8s-container](https://github.com/inspec/train-k8s-container)** | inspec/train-k8s-container | Container Platform | ✅ Active | May 2024 |
| **[train-kubernetes](https://github.com/inspec/train-kubernetes)** | inspec/train-kubernetes | Container Platform | ✅ Active | Apr 2024 |
| **[train-habitat](https://github.com/inspec/train-habitat)** | inspec/train-habitat | Application Platform | 🔶 Low activity | Mar 2024 |
| **[train-alicloud](https://github.com/inspec/train-alicloud)** | inspec/train-alicloud | Cloud Platform | 🔶 Low activity | Dec 2023 |
| **[train-digitalocean](https://github.com/inspec/train-digitalocean)** | inspec/train-digitalocean | Cloud Platform | ⚠️ Stale | Sep 2021 |

### Educational and Example Plugins

| Plugin | Purpose | Complexity | Learning Focus |
|--------|---------|------------|----------------|
| **[train-local-rot13](https://github.com/inspec/train/tree/master/examples/plugins/train-local-rot13)** | Learning example | Beginner | Basic plugin structure |
| **[train-test-fixture](https://rubygems.org/gems/train-test-fixture)** | Testing support | Intermediate | Test strategy patterns |

---

## Organization Ecosystem

### Prospectra (Thomas Heinen)
**GitHub**: https://github.com/orgs/prospectra/repositories  
**Focus**: Enterprise automation and API integration

**Plugins Maintained**:
- **train-rest** - Generic REST API transport for web services
- **train-awsssm** - AWS Systems Manager integration for cloud infrastructure
- **train-telnet** - Direct telnet connectivity for legacy network devices

**Quality Indicators**:
- ✅ Consistent gem naming conventions
- ✅ Comprehensive README documentation
- ✅ Regular maintenance and updates
- ✅ Following semantic versioning
- ✅ Apache 2.0 licensing

### MITRE SAF Team
**GitHub**: https://github.com/mitre/  
**Focus**: Security automation framework and compliance

**Plugins Maintained**:
- **train-juniper** - Juniper Networks device automation for infrastructure compliance
- **train-pwsh** - PowerShell-based Windows automation for security assessments

**Quality Indicators**:
- ✅ Government-grade security standards
- ✅ Comprehensive documentation with modular guides
- ✅ Lawyer-approved licensing (LICENSE, NOTICE, CODE_OF_CONDUCT)
- ✅ Production-ready enterprise features (proxy, bastion)
- ✅ Complete test coverage including mock modes

### InSpec Team (Chef/Progress)
**GitHub**: https://github.com/inspec/  
**Focus**: Core platform and official integrations

**Plugins Maintained**:
- **train-k8s-container** - Kubernetes container platform integration
- **train-local-rot13** - Official plugin development example
- **Core transports** - Built-in SSH, WinRM, cloud providers

**Quality Indicators**:
- ✅ Official support and maintenance
- ✅ Integration with InSpec release cycle
- ✅ Comprehensive testing in CI/CD
- ✅ Documentation in official InSpec docs

---

## Plugin Categories

### 1. Network Device Automation

```ruby
# Characteristics
- SSH-based connectivity with device-specific prompt handling
- Network operating system platform detection
- Configuration file access and parsing
- SNMP integration for monitoring data
```

**Examples**:
- **train-juniper** - JunOS devices (routers, switches, firewalls)
- **train-telnet** - Legacy devices requiring telnet
- **train-cisco-ios** - Cisco IOS/IOS-XE devices (community developed)

**Common Patterns**:
```ruby
class Connection < Train::Plugins::Transport::BaseConnection
  def run_command_via_connection(cmd)
    session.cmd(cmd)  # Handle device prompts
  end
  
  def file_via_connection(path)
    # Map file paths to device commands
    case path
    when %r{^/config/}
      show_config_section(path)
    when %r{^/operational/}
      show_operational_data(path)
    end
  end
end
```

### 2. Cloud Service Integration

```ruby
# Characteristics
- SDK-based API communication
- IAM and credential management
- Asynchronous operation handling
- Multi-region support
```

**Examples**:
- **train-awsssm** - AWS Systems Manager for EC2 fleet management
- **train-aws** (core) - AWS API integration
- **train-azure** (core) - Microsoft Azure cloud services
- **train-gcp** (core) - Google Cloud Platform integration

**Common Patterns**:
```ruby
class Connection < Train::Plugins::Transport::BaseConnection
  def initialize(options)
    @client = build_cloud_client(options)
    super(options)
  end
  
  def run_command_via_connection(cmd)
    # Async execution through cloud APIs
    job = @client.send_command(target_resource, cmd)
    wait_for_completion(job.id)
  end
end
```

### 3. API and Web Service Transport

```ruby
# Characteristics
- HTTP/HTTPS-based communication
- Authentication token management
- REST/GraphQL/RPC protocol support
- JSON/XML response parsing
```

**Examples**:
- **train-rest** - Generic REST API transport

**Common Patterns**:
```ruby
class Connection < Train::Plugins::Transport::BaseConnection
  def run_command_via_connection(cmd)
    endpoint = map_command_to_endpoint(cmd)
    response = @http_client.get(endpoint)
    CommandResult.new(response.body, response.status == 200 ? 0 : 1)
  end
end
```

### 4. Container Platform Integration

```ruby
# Characteristics
- Container runtime API integration
- Multi-container support
- Namespace and context awareness
- Image and registry management
```

**Examples**:
- **train-k8s-container** - Kubernetes pod execution
- **train-docker** (core) - Docker container access
- **train-podman** (core) - Podman container access

**Common Patterns**:
```ruby
class Connection < Train::Plugins::Transport::BaseConnection
  def run_command_via_connection(cmd)
    container_exec_cmd = build_container_command(cmd)
    execute_container_command(container_exec_cmd)
  end
end
```

### 5. Windows Automation

```ruby
# Characteristics
- PowerShell command execution
- WinRM or SSH transport
- Windows-specific path handling
- Registry and service management
```

**Examples**:
- **train-pwsh** - PowerShell automation framework
- **train-winrm** (core) - Windows Remote Management

**Common Patterns**:
```ruby
class Connection < Train::Plugins::Transport::BaseConnection
  def run_command_via_connection(cmd)
    powershell_cmd = "powershell.exe -Command \"#{escape_powershell(cmd)}\""
    execute_windows_command(powershell_cmd)
  end
end
```

---

## Quality Assessment

### Plugin Quality Matrix

| Quality Aspect | Excellent (A) | Good (B) | Needs Work (C) | Poor (D) |
|----------------|---------------|----------|----------------|----------|
| **Documentation** | Complete README, examples, API docs | Good README, basic examples | Minimal docs | No documentation |
| **Testing** | >90% coverage, CI/CD, multiple scenarios | >70% coverage, basic CI | Some tests | No tests |
| **Maintenance** | Regular updates, issue responses | Periodic updates | Infrequent updates | Abandoned |
| **Standards** | Follows all conventions | Minor deviations | Some issues | Many issues |
| **Security** | Secure defaults, input validation | Basic security | Some vulnerabilities | Security issues |

### Current Plugin Ratings

| Plugin | Documentation | Testing | Maintenance | Standards | Security | Overall |
|--------|---------------|---------|-------------|-----------|----------|---------|
| **train-juniper** | A | A | A | A | A | **A** |
| **train-rest** | B | B | A | A | B | **B+** |
| **train-awsssm** | B | B | A | A | A | **B+** |
| **train-pwsh** | A | B | A | A | A | **A-** |
| **train-k8s-container** | A | A | A | A | A | **A** |
| **train-telnet** | B | C | B | B | C | **C+** |

---

## Contributing Guidelines

### Creating New Community Plugins

#### 1. Research Phase
```bash
# Check if similar plugin exists
gem search train-*
inspec plugin list --all

# Study community patterns
git clone https://github.com/prospectra/train-rest
git clone https://github.com/mitre/train-juniper
```

#### 2. Development Standards
```ruby
# Required files structure
lib/train-yourname/
├── transport.rb      # Plugin registration
├── connection.rb     # Core implementation  
├── platform.rb       # Platform detection
└── version.rb        # Version management

# Required documentation
README.md             # Usage and installation
LICENSE              # Apache 2.0 recommended
NOTICE               # Attribution requirements
CODE_OF_CONDUCT.md   # Community standards
```

#### 3. Naming Conventions
```ruby
# Gem naming
gem_name = "train-#{target_system}"  # train-juniper, train-rest

# Module naming
module TrainPlugins
  module YourSystem
    class Transport < Train.plugin(1)
      name "yoursystem"  # Must match URI scheme
    end
  end
end
```

#### 4. Quality Checklist
- [ ] Comprehensive README with examples
- [ ] Test coverage >80% with mock mode
- [ ] Follows semantic versioning
- [ ] Apache 2.0 license or compatible
- [ ] Environment variable support
- [ ] Error handling and logging
- [ ] CI/CD pipeline setup
- [ ] Security review completed

### Plugin Submission Process

#### 1. Development
```bash
# Use plugin template
git clone https://github.com/inspec/train-template-plugin
cd train-template-plugin
./setup.sh yourname

# Follow development guide
# Complete implementation
# Add comprehensive tests
```

#### 2. Quality Review
```bash
# Run quality checks
bundle exec rake test
bundle exec rake lint
bundle audit check
gem build train-yourname.gemspec
```

#### 3. Publication
```bash
# Publish to RubyGems
gem push train-yourname-1.0.0.gem

# Create GitHub release
git tag v1.0.0
git push origin v1.0.0
```

#### 4. Community Registration
- Add to this community directory
- Submit to InSpec plugin registry
- Announce on Chef Community Slack
- Create documentation PR

---

## Community Resources

### Communication Channels

**Chef Community Slack**: https://community-slack.chef.io  
**Channels**:
- `#inspec` - General InSpec discussion
- `#inspec-train` - Train plugin development
- `#chef-oss-practices` - Open source best practices

**GitHub Discussions**:
- [InSpec Discussions](https://github.com/inspec/inspec/discussions)
- [Train Discussions](https://github.com/inspec/train/discussions)

### Learning Resources

**Official Documentation**:
- [InSpec Docs](https://docs.chef.io/inspec/) - Official InSpec documentation
- [Train Plugin Development](https://github.com/inspec/train/blob/master/docs/plugins.md) - Official plugin guide
- [InSpec Plugin Development](https://docs.chef.io/inspec/plugins/) - InSpec plugin system

**Community Guides**:
- [This Plugin Development Guide](README.md) - Comprehensive modular guide
- [Train Juniper Implementation](https://github.com/mitre/train-juniper) - Complete working example
- [Community Plugin Examples](https://github.com/prospectra) - Multiple plugin patterns

### Development Tools

**Plugin Templates**:
```bash
# Official template (if available)
gem install train-plugin-template
train-plugin-template generate yourname

# Manual setup using existing patterns
git clone https://github.com/inspec/train/tree/master/examples/plugins/train-local-rot13
```

**Testing Tools**:
```ruby
# Test with real InSpec
inspec plugin install ./train-yourname-0.1.0.gem
inspec detect -t yourname://test-device

# Automated testing
gem 'minitest'
gem 'mocha'  # For mocking
gem 'vcr'    # For API testing
```

### Plugin Registry

**RubyGems**: https://rubygems.org/search?query=train-  
**InSpec Plugin Search**: `inspec plugin search train-`

**Installation Pattern**:
```bash
# Standard installation
inspec plugin install train-yourname

# Version-specific
inspec plugin install train-yourname -v 1.2.3

# Development installation
inspec plugin install ./path/to/train-yourname.gem
```

---

## Plugin Discovery

### User Discovery Process

1. **Search RubyGems**: `gem search train-`
2. **InSpec Plugin List**: `inspec plugin list --all`
3. **GitHub Search**: Search for `train-` repositories
4. **Community Recommendations**: Ask in Chef Community Slack

### Plugin Visibility

**Improve Discoverability**:
- Use descriptive gem descriptions
- Add comprehensive tags and keywords
- Maintain up-to-date documentation
- Participate in community discussions
- Provide real-world usage examples

**SEO-Friendly Naming**:
```ruby
# Good - clear target system
"train-juniper"    # Juniper Networks devices
"train-awsssm"     # AWS Systems Manager
"train-k8s-container"  # Kubernetes containers

# Avoid - unclear purpose
"train-helper"     # What does it help with?
"train-connector"  # Connects to what?
```

---

## Ecosystem Health

### Growth Indicators

**Plugin Count**: ~15 community plugins + 8 core transports  
**Active Organizations**: 3 major contributors (Prospectra, MITRE, InSpec)  
**Release Frequency**: Regular updates from active maintainers  
**Quality Trend**: Improving standards and documentation

### Ecosystem Challenges

1. **Documentation Gaps**: Plugin development docs were incomplete
2. **Quality Variance**: Some plugins lack comprehensive testing
3. **Discovery Issues**: Hard to find appropriate plugins for specific use cases
4. **Maintenance Burden**: Some plugins become unmaintained

### Ecosystem Improvements (2023-2024)

1. **Comprehensive Guides**: This modular documentation addresses knowledge gaps
2. **Quality Standards**: Clear assessment criteria and best practices
3. **Community Support**: Better communication channels and resources
4. **Template Plugins**: Standardized starting points for new plugins

### Future Directions

**Technical Evolution**:
- Train Plugin API v2 (potential future enhancement)
- Better testing frameworks and tools
- Improved platform detection system
- Enhanced error handling standards

**Community Growth**:
- More enterprise adoption
- Additional platform support
- Better integration with CI/CD
- Enhanced security features

---

## Recommended Learning Path

### For New Plugin Developers

1. **Start Simple**: Study `train-local-rot13` example
2. **Understand Patterns**: Review this modular guide completely
3. **Pick a Pattern**: Choose SSH, API, Cloud, or Container approach
4. **Study References**: Examine similar existing plugins
5. **Build Incrementally**: Start with basic connectivity, add features gradually
6. **Test Thoroughly**: Use mock mode and real device testing
7. **Document Completely**: README, examples, troubleshooting
8. **Engage Community**: Share progress, ask for feedback

### For Advanced Developers

1. **Study Multiple Patterns**: Compare different plugin architectures
2. **Contribute Improvements**: Enhance existing plugins
3. **Mentor Others**: Help new plugin developers
4. **Drive Standards**: Propose ecosystem improvements
5. **Create Tools**: Build development and testing utilities

---

## Key Takeaways

1. **Strong ecosystem** - Multiple active maintainers and diverse plugin types
2. **Quality focus** - Leading plugins demonstrate excellent practices
3. **Community support** - Good communication channels and resources
4. **Documentation improvement** - This guide addresses previous knowledge gaps
5. **Growth potential** - Room for new plugins and enhanced standards
6. **Enterprise ready** - Several plugins meet production requirements
7. **Learning resources** - Multiple examples and patterns available

The Train plugin ecosystem is healthy and growing, with excellent examples to learn from and a supportive community for new contributors.

---

**Congratulations!** You've completed the comprehensive Train Plugin Development Guide. You now have the knowledge to build production-ready plugins following community best practices.

**For performance optimization**, see [Performance Patterns](14-performance-patterns.md) for real-world optimization strategies used in production plugins.
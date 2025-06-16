# Train Plugin Development Guide

A comprehensive, modular guide to developing Train plugins based on real-world experience building train-juniper.

## Guide Structure

This guide is broken into focused documents covering specific aspects of Train plugin development:

### 🚀 Getting Started
- **[Plugin Basics](01-plugin-basics.md)** - What is Train, why plugins matter, core concepts
- **[Development Setup](02-development-setup.md)** - Environment setup, project structure, dependencies

### 🏗️ Core Implementation  
- **[Plugin Architecture](03-plugin-architecture.md)** - 4-file structure, Train API, registration patterns
- **[URI Design Patterns](04-uri-design-patterns.md)** - Different URI styles, parsing, option handling
- **[Connection Implementation](05-connection-implementation.md)** - Connection class, command execution, file operations

### 🌐 Enterprise Features
- **[Proxy and Authentication](06-proxy-authentication.md)** - Bastion hosts, proxy commands, enterprise connectivity
- **[Platform Detection](07-platform-detection.md)** - Platform registry, detection strategies, force_platform!
- **[Testing Strategies](08-testing-strategies.md)** - Unit tests, integration tests, mock mode

### 📦 Production Ready
- **[Packaging and Publishing](09-packaging-publishing.md)** - Gemspec, versioning, RubyGems publication  
- **[Best Practices](10-best-practices.md)** - Error handling, performance, security
- **[Troubleshooting](11-troubleshooting.md)** - Common issues, debugging, community resources

### 📚 Reference
- **[Real-World Examples](12-real-world-examples.md)** - train-juniper, REST APIs, cloud resources, containers
- **[Performance Patterns](14-performance-patterns.md)** - Real-world optimization strategies and connection reuse patterns
- **[Community Plugins](13-community-plugins.md)** - Plugin directory, quality standards, contribution guidelines

## Why This Guide Exists

The existing Train plugin documentation is scattered and incomplete. This guide was created during the development of the train-juniper plugin to provide:

- **Complete examples** based on real implementations
- **Enterprise-ready patterns** for production environments  
- **Clear learning path** from basics to advanced topics
- **Multiple plugin styles** covering different use cases

## Who This Guide Is For

- **Plugin Developers**: Building new Train transports for specific technologies
- **Network Engineers**: Enabling InSpec for network devices and infrastructure
- **DevOps Teams**: Integrating custom systems with InSpec compliance testing
- **Security Teams**: Creating compliance automation for specialized environments

## Prerequisites

- Ruby 3.0+ development experience
- Basic understanding of InSpec and compliance testing
- Familiarity with target systems you want to connect to
- Experience with SSH, APIs, or other connection protocols

## Quick Start

1. Read [Plugin Basics](01-plugin-basics.md) to understand Train's role
2. Follow [Development Setup](02-development-setup.md) to create your project
3. Implement the [Plugin Architecture](03-plugin-architecture.md) 4-file structure
4. Choose your [URI Design Pattern](04-uri-design-patterns.md) based on target audience
5. Build your [Connection Implementation](05-connection-implementation.md)
6. Add [Testing](08-testing-strategies.md) and publish following [Packaging guide](09-packaging-publishing.md)

## Contributing to This Guide

This guide was created during train-juniper development for MITRE's Security Automation Framework. Improvements and additions are welcome:

- **Technical Questions**: [saf@mitre.org](mailto:saf@mitre.org)
- **Documentation Issues**: Submit GitHub issues
- **Community Examples**: Submit PRs with new plugin patterns
- **Best Practices**: Share lessons learned from your plugin development

## License and Attribution

This guide is part of the train-juniper project, licensed under Apache-2.0.

Based on research of community plugins including:
- **train-rest** by Thomas Heinen (Prospectra)
- **train-awsssm** by Thomas Heinen (Prospectra) 
- **train-k8s-container** by InSpec Team
- **train-local-rot13** by InSpec Team (official example)

© 2025 The MITRE Corporation
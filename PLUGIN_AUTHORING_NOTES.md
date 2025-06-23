# Plugin Authoring Notes - Lessons from train-juniper Development

## Overview
This document captures key lessons learned during train-juniper development that should be incorporated into the train plugin development guide.

## Key Lessons Learned

### 1. Environment Variable Handling
- **Lesson**: Empty strings are truthy in Ruby - use proper validation
- **Example**: `ENV['VAR'] || default` fails when VAR=""
- **Best Practice**: Create helper methods like `env_value` and `env_int`
```ruby
def env_value(key)
  value = ENV.fetch(key, nil)
  return nil if value.nil? || value.empty?
  value
end
```

### 2. Security Considerations
- Command sanitization patterns (allow pipes for network devices)
- Input validation for all connection parameters
- Safe logging with credential redaction
- SSH_ASKPASS for bastion password automation

### 3. Code Organization
- 500+ line files indicate need for modularization
- Extract logical groupings into modules
- Use dependency injection for testability
- Separate concerns (connection, validation, execution)

### 4. Testing Patterns
- Mock mode should be comprehensive
- Extract mock data to separate modules
- Test security edge cases explicitly
- Maintain high coverage (target 80%+)

### 5. Documentation
- YARD documentation for all public methods
- Include usage examples in method docs
- API documentation page in MkDocs
- Windows setup guide for cross-platform support

### 6. Release Process
- Automate with GitHub Actions
- Use trusted publishing for RubyGems
- Automate changelog generation
- Update navigation files automatically

### 7. Refactoring Strategies
- Break large methods into smaller focused ones
- Extract related functionality into modules
- Use composition over inheritance
- Plan refactoring in phases

## Topics to Add to Plugin Development Guide

1. **Advanced Environment Configuration**
2. **Security Hardening for Plugins**
3. **Modular Architecture Patterns**
4. **Comprehensive Mock Systems**
5. **Cross-Platform Considerations**
6. **CI/CD Best Practices**
7. **Refactoring Legacy Code**

## Additional Lessons from Current Session

### 8. Dependency Management
- Follow RubyGems standards: dev dependencies in gemspec, not Gemfile
- Version dependencies carefully for compatibility (e.g., ffi for Windows)
- Remove tool-specific dependencies (Brakeman for Rails, not gems)

### 9. Error Messages
- Verify error messages match actual capabilities
- Provide actionable troubleshooting steps
- Include relevant configuration values in errors
- Don't claim limitations that don't exist

### 10. Incremental Refactoring
- Analyze current state before refactoring (line counts, methods)
- Create visual diagrams for architecture changes
- Document benefits and risks
- Plan phases to minimize disruption

### 11. Context Management
- Use recovery prompts for long-running projects
- Create session summaries at natural break points
- Track decisions and rationale
- Maintain continuity across sessions

### 12. Release Automation
- Disable bundler gem tasks if using GitHub Actions
- Automate all documentation updates (mkdocs, changelogs)
- Use OIDC/trusted publishing to avoid MFA issues
- Create helper methods for version detection patterns

### 13. Module Extraction Patterns
- Start with low-risk extractions: constants, helpers, nested classes
- Include modules with `include ModuleName` for mixins
- Move files to separate module files: `require 'train-plugin/module_name'`
- Maintain same public API during refactoring
- Use RuboCop auto-correct for consistent style

### 14. Refactoring Large Files
- 500+ line files are candidates for modularization
- Extract by logical groupings: validation, helpers, nested classes
- Connection.rb reduced from 583 to 480 lines (18% reduction)
- Keep modules focused on single responsibility
- Test after each extraction to ensure no regressions

### 15. Testing Modular Code
- Tests should continue passing after module extraction
- Coverage should remain stable or improve
- Use integration tests to verify module interactions
- Module boundaries enable better unit testing

### 16. Directory Structure for Plugins
- **Core Plugin Files**: Keep at root (connection.rb, transport.rb, platform.rb, version.rb)
- **Supporting Modules**: Organize into subdirectories:
  - `connection/` - Connection-related modules (validation, ssh, bastion)
  - `helpers/` - Utility modules (environment, mock data)
  - `file_abstraction/` - File operation classes
- **Git Strategy**: Use `git mv` to preserve history
- **Module Naming**: Update module names when renaming files (EnvironmentHelpers → Environment)
- **Import Order**: Platform first, then connection modules, then helpers
- **Testing**: Verify all tests pass after reorganization

### 17. Task Matrix for Large Refactoring
- Track each module extraction with status, lines, location
- Calculate reduction percentages to show progress
- Set target line counts for main classes
- Group by phases to manage complexity
- Update after each extraction

### 18. Module Design Principles
- **Single Responsibility**: Each module does one thing well
- **Minimal Public API**: Only expose what's needed
- **Clear Dependencies**: Explicit requires and includes
- **Testable in Isolation**: Modules should be unit testable
- **Documentation**: YARD docs for all public methods

### 19. Modularization Best Practices
- **Avoid Naming Conflicts**: Module names shouldn't conflict with existing classes
- **Use Fully Qualified Names**: Train::Extras::CommandResult instead of CommandResult
- **Instance Variable Access**: Modules can access host class instance variables (@options, @logger)
- **Method Dependencies**: Modules can call methods from other included modules
- **Include Order Matters**: Include modules in dependency order

### 20. Refactoring Monolithic Classes
- **Target Line Count**: Aim for classes under 250-300 lines
- **Extract by Responsibility**: Group related methods into focused modules
- **Maintain Public API**: Keep the same public interface during refactoring
- **Test Coverage**: Modular code often improves testability and coverage
- **Directory Structure**: Organize modules by function (connection/, helpers/)

### 21. Module Design Patterns
- **Single Responsibility**: Each module should do one thing well
- **Cohesive Methods**: All methods in a module should be related
- **Private Methods**: Modules can have private sections for internal logic
- **Constants**: Define module-specific constants within the module
- **Documentation**: Each module needs clear YARD documentation

### 22. Cross-Module Communication
- **Shared State**: Via instance variables from the host class
- **Method Calls**: Modules can call methods from other included modules
- **Constants**: Use fully qualified names or create aliases
- **Error Handling**: Modules can raise and rescue exceptions across boundaries

### 23. Coverage Analysis Tools
- **Create Reusable Scripts**: utils/coverage_analysis.rb pattern
- **Multiple Output Formats**: Support human, JSON, markdown
- **SimpleCov Integration**: Parse coverage/.last_run.json
- **:nocov: Detection**: Properly handle excluded code blocks
- **Actionable Output**: Provide specific file locations and recommendations

### 24. Achieving 100% Test Coverage
- **SimpleCov Configuration**: Enable nocov_token support
  ```ruby
  SimpleCov.start do
    enable_coverage :branch
    nocov_token 'nocov'
  end
  ```
- **Marking Untestable Code**: Use :nocov: for real SSH connections
- **Edge Case Testing**: Test early returns and guard clauses
- **Coverage != Quality**: Focus on meaningful tests, not just numbers

### 25. DRY Patterns for Plugins
- **Command Result Factory**: Reduce duplication
  ```ruby
  def success_result(output, cmd = nil)
    output = clean_output(output, cmd) if cmd
    Train::Extras::CommandResult.new(output, '', 0)
  end
  ```
- **Logging Helpers**: Consistent, secure logging
- **Constants Module**: Centralize configuration values
- **Helper Methods**: Extract repeated patterns

### 26. Production Release Process
- **Standard Conventions**: Build gems in pkg/ directory
- **Coverage Integration**: Generate reports during release
- **Automated Updates**: mkdocs.yml, CHANGELOG.md
- **GitHub Actions**: Use OIDC for trusted publishing
- **Documentation Links**: Remove .md extensions for MkDocs

### 27. RuboCop Compliance Strategies
- **Auto-Fix First**: Use `rubocop -a` for safe fixes
- **Refactor Complex Methods**: Break down ABC complexity
- **Extract Helper Methods**: Reduce method length
- **Avoid Todos**: Fix all issues immediately
- **Document Decisions**: Comment non-obvious style choices

### 28. Material for MkDocs Integration
- **Admonition Boxes**: Use !!! note, warning, info
- **Empty Lines**: Required before bullet lists
- **Subsection Structure**: Use ### for better hierarchy
- **Code Annotations**: Add numbered annotations with .annotate
- **Material Icons**: :material-star: for visual enhancement

### 29. Cross-Platform Support and Bundler Platforms
- **Platform Management**: Essential for gems that work across different operating systems
- **Bundler 2.2+ Changes**: No longer includes 'ruby' platform by default
- **CI/CD Failures**: Missing platforms cause "Your bundle only supports platforms..." errors
- **Adding Platforms**: Use `bundle lock --add-platform PLATFORM_NAME`
- **Platform-Specific Gems**: Some gems have native extensions (ffi, nokogiri, etc.)

#### Recommended Platform Support for Train Plugins
```bash
# Core platforms for maximum compatibility
bundle lock --add-platform ruby              # Platform-independent fallback
bundle lock --add-platform x86_64-linux      # Standard Linux
bundle lock --add-platform x64-mingw-ucrt    # Modern Windows
bundle lock --add-platform x86_64-darwin     # Intel macOS
bundle lock --add-platform arm64-darwin-23   # GitHub Actions macOS runners
bundle lock --add-platform arm64-darwin-24   # Local Apple Silicon Macs

# Additional recommended platforms
bundle lock --add-platform aarch64-linux     # ARM64 Linux (AWS Graviton)
bundle lock --add-platform x86_64-linux-musl # Alpine Linux (containers)

# Network/Enterprise environments
bundle lock --add-platform x86_64-freebsd    # FreeBSD (relevant for JunOS)
bundle lock --add-platform x86_64-solaris    # Solaris/illumos
```

#### Platform Considerations
- **Development Platforms**: Add your local platform automatically on `bundle install`
- **CI/CD Platforms**: Must be added explicitly before pushing
- **Deployment Platforms**: Consider where users will run your plugin
- **Container Platforms**: Alpine (musl) common in Docker environments
- **Network Devices**: FreeBSD relevant for Juniper (JunOS based on FreeBSD)

#### Checking Current Platforms
```bash
# View platforms in Gemfile.lock
grep -A 20 "^PLATFORMS" Gemfile.lock

# Show current platform
ruby -e "puts RUBY_PLATFORM"

# List all platforms for installed gems
bundle platform
```

#### Platform Testing Strategy
- **Primary Testing**: Linux, macOS, Windows in CI/CD
- **Secondary Testing**: Containers, ARM platforms
- **Platform-Specific Code**: Use `:nocov:` markers for untestable paths
- **Conditional Logic**: Use `Gem.win_platform?` or `RUBY_PLATFORM` checks

## Topics for Future Development
- Dependency injection patterns for testability
- Performance considerations for modular vs monolithic code
- Backward compatibility strategies during major refactoring
- Testing strategies for modular plugin architectures
- InSpec resource pack development patterns
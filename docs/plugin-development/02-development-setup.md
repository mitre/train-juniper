# Development Setup

Setting up your environment and project structure for Train plugin development.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Ruby Development Environment](#ruby-development-environment)
3. [Project Initialization](#project-initialization)
4. [Directory Structure](#directory-structure)
5. [Dependency Management](#dependency-management)
6. [Testing Setup](#testing-setup)
7. [Development Workflow](#development-workflow)

---

## Prerequisites

### Required Software

- **Ruby 3.0+** - Train requires modern Ruby
- **Bundler** - Dependency management
- **Git** - Version control
- **Your target system** - Real or simulated environment for testing

### Recommended Tools

- **RuboCop** - Code linting and style
- **Pry** - Interactive debugging
- **Docker/Podman** - For containerized testing environments
- **Your favorite editor** - VS Code, RubyMine, Vim, etc.

### Understanding Your Target System

Before coding, thoroughly understand what you're connecting to:

- **Connection method**: SSH, HTTP, WebSocket, serial, custom protocol?
- **Authentication**: Username/password, API keys, certificates, cloud IAM?
- **Command interface**: CLI commands, API endpoints, database queries?
- **File access**: File system, configuration APIs, object storage?
- **Platform identification**: How to detect system type and version?

---

## Ruby Development Environment

### Installing Ruby

**Using rbenv (recommended):**
```bash
# Install rbenv
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash

# Install latest Ruby
rbenv install 3.1.6
rbenv global 3.1.6
rbenv rehash
```

**Using RVM:**
```bash
# Install RVM
curl -sSL https://get.rvm.io | bash

# Install Ruby
rvm install 3.1.6
rvm use 3.1.6 --default
```

**Verify installation:**
```bash
ruby --version
# => ruby 3.1.6p260 (2023-01-01 revision 1234567) [x86_64-linux]

gem --version
# => 3.4.10
```

### Install Bundler

```bash
gem install bundler
bundler --version
# => Bundler version 2.4.10
```

---

## Project Initialization

### Create Project Structure

```bash
# Create project directory
mkdir train-yourname
cd train-yourname

# Initialize git repository
git init

# Create basic directory structure
mkdir -p lib/train-yourname
mkdir -p test/{unit,functional,integration}
mkdir -p docs

# Create essential files
touch lib/train-yourname.rb
touch lib/train-yourname/version.rb
touch lib/train-yourname/transport.rb
touch lib/train-yourname/connection.rb
touch lib/train-yourname/platform.rb
```

### Project Directory Structure

```
train-yourname/
├── lib/
│   ├── train-yourname.rb              # Entry point
│   └── train-yourname/
│       ├── version.rb                 # Version constant
│       ├── transport.rb               # Plugin registration
│       ├── connection.rb              # Core implementation
│       └── platform.rb                # Platform detection
├── test/
│   ├── helper.rb                      # Test setup
│   ├── unit/
│   │   ├── transport_test.rb          # Transport tests
│   │   └── connection_test.rb         # Connection tests
│   ├── functional/
│   │   └── yourname_test.rb           # End-to-end tests
│   └── integration/
│       └── proxy_test.rb              # Complex scenario tests
├── docs/
│   └── README.md                      # Plugin documentation
├── .gitignore                         # Git ignore patterns
├── .ruby-version                      # Ruby version specification
├── Gemfile                           # Dependencies
├── Rakefile                          # Build tasks
├── train-yourname.gemspec            # Gem specification
└── README.md                         # Project overview
```

---

## Dependency Management

### Create Gemfile

```ruby
# Gemfile
source "https://rubygems.org"

# Specify Ruby version
ruby "3.1.6"

# Train dependency - use train-core for lighter weight
gem "train-core", "~> 3.12"

# Add your specific dependencies
gem "net-ssh", "~> 7.0"          # For SSH connections
# gem "rest-client", "~> 2.1"    # For REST APIs
# gem "aws-sdk-core", "~> 3.0"   # For AWS services
# gem "kubernetes-client", "~> 4.0" # For Kubernetes

# Development dependencies
group :development, :test do
  gem "rake", "~> 13.0"
  gem "minitest", "~> 5.0"
  gem "rubocop", "~> 1.21"
  gem "pry", "~> 0.14"
  gem "simplecov", "~> 0.21"      # Code coverage
end
```

### Ruby Version File

```bash
# .ruby-version
3.1.6
```

### Install Dependencies

```bash
bundle install
```

---

## Testing Setup

### Test Helper

```ruby
# test/helper.rb
require "minitest/autorun"
require "minitest/spec"
require "simplecov" if ENV["COVERAGE"]

# Start SimpleCov if coverage is enabled
if ENV["COVERAGE"]
  SimpleCov.start do
    add_filter "/test/"
    minimum_coverage 80
  end
end

# Load the plugin
require "train"
require_relative "../lib/train-yourname"

# Test utilities
def mock_options
  {
    mock: true,
    host: "test.example.com",
    user: "testuser",
    password: "testpass"
  }
end

def real_device_available?
  ENV["REAL_DEVICE_HOST"] && ENV["REAL_DEVICE_USER"]
end

def real_device_options
  {
    host: ENV["REAL_DEVICE_HOST"],
    user: ENV["REAL_DEVICE_USER"],
    password: ENV["REAL_DEVICE_PASSWORD"],
    timeout: 30
  }
end
```

### Rakefile

```ruby
# Rakefile
require "rake/testtask"
require "rubocop/rake_task"

# Default task runs tests
task default: :test

# Test task
Rake::TestTask.new do |t|
  t.libs.push "lib"
  t.test_files = FileList[
    "test/unit/*_test.rb",
    "test/functional/*_test.rb",
    "test/integration/*_test.rb"
  ]
  t.verbose = true
  t.warning = false  # Reduce noise from dependencies
end

# Linting task
RuboCop::RakeTask.new(:lint) do |t|
  t.options = ["--display-cop-names", "--config", ".rubocop.yml"]
end

# Coverage task
task :coverage do
  ENV["COVERAGE"] = "true"
  Rake::Task[:test].invoke
end

# Clean task
task :clean do
  FileUtils.rm_rf "coverage"
  FileUtils.rm_rf "*.gem"
end

# Build gem
task :build do
  system "gem build train-yourname.gemspec"
end

# Install gem locally
task :install => :build do
  gem_file = Dir["train-yourname-*.gem"].first
  system "gem install #{gem_file}"
end
```

---

## Development Workflow

### Basic Development Loop

```bash
# 1. Make changes to your plugin
vim lib/train-yourname/connection.rb

# 2. Run tests
bundle exec rake test

# 3. Check code style
bundle exec rake lint

# 4. Run with coverage
bundle exec rake coverage

# 5. Test manually
bundle exec ruby -e "
require './lib/train-yourname'
transport = Train.create('yourname', mock: true)
puts transport.connection.run_command('test').stdout
"
```

### Git Workflow

```bash
# Create feature branch
git checkout -b feature/add-authentication

# Make changes and test
bundle exec rake test

# Commit changes
git add .
git commit -m "Add authentication support

- Implement basic username/password auth
- Add environment variable support  
- Update tests for new auth flow"

# Push and create PR
git push origin feature/add-authentication
```

### Environment Variables for Testing

```bash
# .env (don't commit this file!)
# Real device testing
YOURNAME_HOST=device.example.com
YOURNAME_USER=admin
YOURNAME_PASSWORD=secret123

# Proxy testing
YOURNAME_BASTION_HOST=jump.example.com
YOURNAME_BASTION_USER=netops

# AWS/Cloud testing  
AWS_REGION=us-west-2
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
```

### Testing Against Real Systems

```bash
# Mock testing (fast, no real connections)
bundle exec rake test

# Real device testing (slower, requires actual device)
REAL_DEVICE_HOST=device.corp.com \
REAL_DEVICE_USER=admin \
REAL_DEVICE_PASSWORD=secret \
bundle exec rake test

# Proxy testing
YOURNAME_HOST=internal.device \
YOURNAME_BASTION_HOST=jump.corp.com \
bundle exec ruby test_proxy.rb
```

---

## IDE and Editor Setup

### VS Code Configuration

Create `.vscode/settings.json`:
```json
{
  "ruby.lint": {
    "rubocop": true
  },
  "ruby.format": "rubocop",
  "files.associations": {
    "Gemfile": "ruby",
    "Rakefile": "ruby",
    "*.gemspec": "ruby"
  },
  "search.exclude": {
    "coverage/**": true,
    "*.gem": true
  }
}
```

### RuboCop Configuration

Create `.rubocop.yml`:
```yaml
# .rubocop.yml
require:
  - rubocop-minitest

AllCops:
  TargetRubyVersion: 3.1
  NewCops: enable
  Exclude:
    - 'vendor/**/*'
    - 'coverage/**/*'
    - '*.gemspec'

# Adjust line length for readability
Layout/LineLength:
  Max: 120

# Allow longer methods for connection logic
Metrics/MethodLength:
  Max: 30

# Allow longer classes for main connection class
Metrics/ClassLength:
  Max: 250

# Don't require class documentation (plugins are self-documenting)
Style/Documentation:
  Enabled: false

# Allow empty rescue for graceful degradation
Lint/SuppressedException:
  Enabled: false
```

---

## Debugging and Development Tools

### Using Pry for Debugging

```ruby
# In your connection.rb
require "pry"

def connect
  binding.pry  # Debug point
  # Your connection logic here
end
```

### Logging Setup

```ruby
# In connection.rb initialize()
def initialize(options)
  @logger = options[:logger] || Logger.new(STDOUT, level: Logger::WARN)
  
  # Enable debug logging during development
  @logger.level = Logger::DEBUG if ENV["DEBUG"]
end
```

### Manual Testing Script

Create `test_manual.rb`:
```ruby
#!/usr/bin/env ruby
require "bundler/setup"
require "./lib/train-yourname"

# Manual testing
puts "=== Testing train-yourname plugin ==="

# Test with mock
puts "\n1. Mock connection test:"
transport = Train.create("yourname", mock: true)
connection = transport.connection
result = connection.run_command("show version")
puts "Mock result: #{result.stdout}"

# Test with real device (if available)
if ENV["REAL_DEVICE_HOST"]
  puts "\n2. Real device test:"
  real_transport = Train.create("yourname", {
    host: ENV["REAL_DEVICE_HOST"],
    user: ENV["REAL_DEVICE_USER"],
    password: ENV["REAL_DEVICE_PASSWORD"]
  })
  real_connection = real_transport.connection
  real_result = real_connection.run_command("show version")
  puts "Real result: #{real_result.stdout[0..100]}..."
end

puts "\n=== Testing complete ==="
```

Run with:
```bash
bundle exec ruby test_manual.rb
```

---

## Troubleshooting Common Setup Issues

### Gem Loading Issues

```ruby
# If you get "cannot load such file" errors:
# 1. Check your $LOAD_PATH setup in lib/train-yourname.rb
libdir = File.dirname(__FILE__)
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

# 2. Verify file naming matches exactly
# lib/train-yourname.rb (not train_yourname.rb)
# lib/train-yourname/connection.rb
```

### Bundle Installation Issues

```bash
# If bundle install fails:
# 1. Clear bundler cache
bundle cache clean --force

# 2. Update bundler
gem update bundler

# 3. Try specific train version
# In Gemfile: gem "train-core", "= 3.12.13"
```

### Ruby Version Issues

```bash
# If Ruby version conflicts:
# 1. Check .ruby-version file exists
echo "3.1.6" > .ruby-version

# 2. Restart your shell
# 3. Verify Ruby version
ruby --version
```

---

## Next Steps

With your development environment set up:

1. **[Plugin Architecture](03-plugin-architecture.md)** - Implement the 4-file structure
2. **[URI Design Patterns](04-uri-design-patterns.md)** - Choose your connection URI style  
3. **[Connection Implementation](05-connection-implementation.md)** - Build core functionality

---

## Key Takeaways

- **Use train-core dependency** - Lighter weight than full train gem
- **Follow standard Ruby project structure** - Makes collaboration easier
- **Set up testing early** - Mock mode enables rapid development
- **Use environment variables** - Keep credentials out of code
- **Enable debugging tools** - Pry and logging are essential for plugin development

**Next**: Learn about the mandatory [Plugin Architecture](03-plugin-architecture.md).
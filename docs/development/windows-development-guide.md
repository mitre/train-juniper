# Windows Development Guide

This guide covers development and testing of train-juniper on Windows systems, particularly for the plink.exe bastion authentication feature.

## Prerequisites

1. **Windows 10/11** with Ruby 3.1+
2. **PuTTY installed** with plink.exe in PATH
3. **Git Bash or PowerShell**
4. **Bundle** gem installed

## Building and Testing Locally

### 1. Clone and Build the Gem

```powershell
# Clone the repository
git clone https://github.com/mitre/train-juniper.git
cd train-juniper

# Install dependencies
bundle install

# Build the gem
gem build train-juniper.gemspec

# Install the local gem
gem install ./train-juniper-*.gem
```

### 2. Running the Test Suite

```powershell
# Run all tests
bundle exec rake test

# Run linting
bundle exec rake lint

# Run security checks
bundle exec rake security
```

### 3. Testing plink.exe Integration

The repository includes Windows-specific test utilities in `test/utilities/`:

```powershell
# Run the Windows test script (Ruby version)
ruby test/utilities/test_windows_plink.rb

# Or use the PowerShell version
.\test\utilities\test_windows_plink.ps1
```

Expected output:
```
=== Train-Juniper Windows Plink Test ===
Ruby version: 3.1.x
Platform: x64-mingw-ucrt
Windows?: true

Test 1: Checking for plink.exe...
plink.exe found: true
plink.exe location: C:\Program Files\PuTTY\plink.exe

Test 2: Testing mock mode...
Mock command successful: true
Mock output: Hostname: mock-device

Test 3: Testing plink command generation...
Generated plink command:
  plink.exe -batch -ssh -pw test_pass jumpuser@bastion.example.com -nc %h:%p
With custom port:
  plink.exe -batch -ssh -pw test_pass -P 2222 jumpuser@bastion.example.com -nc %h:%p
```

### 4. Testing Real Connections

For testing with actual devices, set environment variables:

```powershell
# Set environment variables
$env:JUNIPER_HOST = "192.168.1.100"
$env:JUNIPER_USER = "admin"
$env:JUNIPER_PASSWORD = "juniper123"
$env:BASTION_HOST = "bastion.example.com"
$env:BASTION_USER = "jumpuser"
$env:BASTION_PASSWORD = "bastion123"

# Run the test
ruby test/utilities/test_windows_plink.rb
```

Or create a `.env` file in the project root:
```
JUNIPER_HOST=192.168.1.100
JUNIPER_USER=admin
JUNIPER_PASSWORD=juniper123
BASTION_HOST=bastion.example.com
BASTION_USER=jumpuser
BASTION_PASSWORD=bastion123
```

## Windows-Specific Behavior

### Before v0.7.4 (Windows)
- ❌ Bastion password auth fails (prompts for password)
- ✅ Direct connections work
- ✅ Bastion with SSH keys works

### After v0.7.4 (Windows with plink.exe)
- ✅ Bastion password auth works automatically
- ✅ Direct connections work  
- ✅ Bastion with SSH keys works
- ✅ Falls back to standard SSH if plink not available

## Debugging Windows Issues

### Common Problems

1. **plink.exe not found**
   - Verify installation: `where plink.exe`
   - Add PuTTY to PATH if needed
   - Default location: `C:\Program Files\PuTTY`

2. **Host key not accepted**
   - Run `plink.exe -ssh user@host` manually first
   - Accept the host key when prompted

3. **Special characters in passwords**
   - Use double quotes in PowerShell
   - Escape with backtick: `` ` ``
   - Example: ``--password "pass`$word"``

### Debug Logging

Enable detailed logging to troubleshoot issues:

```powershell
# Set debug environment variable
$env:TRAIN_JUNIPER_LOG_LEVEL = "debug"

# Run with InSpec debug logging
inspec shell -t juniper://admin@device --password 'pass' `
  --bastion-host jump --bastion-user user `
  --bastion-password 'bastion-pass' -l debug
```

Look for these key messages:
- "Using plink.exe for bastion proxy" - plink is being used
- "Generated plink command: plink.exe -batch -ssh -pw ..." - shows exact command

## Contributing Windows Improvements

When working on Windows-specific features:

1. **Test on multiple Windows versions** - Windows 10 and 11 if possible
2. **Consider Windows paths** - Use `File.join` instead of hardcoded separators
3. **Handle Windows line endings** - Git should handle this automatically
4. **Test with different Ruby versions** - 3.1, 3.2, and 3.3
5. **Document Windows-specific behavior** - Update this guide as needed

## Reporting Windows Issues

When reporting Windows-specific issues, please include:

1. Windows version (`winver`)
2. Ruby version (`ruby -v`)
3. PuTTY/plink version (`plink -V`)
4. Full error messages and stack traces
5. Debug log output if possible

Create issues at: https://github.com/mitre/train-juniper/issues
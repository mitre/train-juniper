# Windows Testing Guide for v0.7.4

This guide helps test the new Windows plink.exe support in train-juniper v0.7.4.

## Prerequisites

1. **Windows 10/11** with Ruby 3.1+
2. **PuTTY installed** with plink.exe in PATH
3. **Git Bash or PowerShell**

## Quick Test Steps

### 1. Install the Development Version

```powershell
# Clone and build the gem
git clone https://github.com/mitre/train-juniper.git
cd train-juniper
bundle install

# Build the gem
gem build train-juniper.gemspec

# Install it
gem install train-juniper-0.7.4.gem
```

### 2. Verify plink.exe is Available

```powershell
# Check if plink is in PATH
where plink.exe

# If not found, add PuTTY to PATH:
# System Properties → Environment Variables → PATH → Add C:\Program Files\PuTTY
```

### 3. Run the Test Script

```powershell
# Run the Windows test script
ruby test_windows_plink.rb
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

### 4. Test Real Connection (Optional)

If you have access to a Juniper device through a bastion:

```powershell
# Set environment variables
SET JUNIPER_HOST=192.168.1.100
SET JUNIPER_USER=admin
SET JUNIPER_PASSWORD=juniper123
SET BASTION_HOST=bastion.example.com
SET BASTION_USER=jumpuser
SET BASTION_PASSWORD=bastion123

# Run the test
ruby test_windows_plink.rb
```

## Manual Testing with InSpec

### Test 1: Direct Connection (No Bastion)

```powershell
# Should work on Windows as before
inspec detect -t juniper://admin@device.example.com --password "secret"
```

### Test 2: Bastion with SSH Keys

```powershell
# Should work on Windows
inspec detect -t juniper://admin@device.internal `
  --bastion-host jump.example.com `
  --bastion-user jumpuser `
  --key-files ~/.ssh/id_rsa
```

### Test 3: Bastion with Password (NEW - plink.exe)

```powershell
# This should now work on Windows with plink.exe!
inspec detect -t juniper://admin@device.internal `
  --bastion-host jump.example.com `
  --bastion-user jumpuser `
  --bastion-password "jump_pass" `
  --password "device_pass"
```

## Debugging

Enable debug logging to see plink.exe usage:

```powershell
# Set debug logging
$env:TRAIN_JUNIPER_LOG_LEVEL = "debug"

# Run with debug output
inspec detect -t juniper://admin@device --bastion-host jump -l debug
```

Look for these debug messages:
- "Using plink.exe for bastion proxy"
- "Generated plink command: plink.exe -batch -ssh -pw ..."

## Troubleshooting

### plink.exe not found
- Install PuTTY: https://www.putty.org
- Add to PATH: `C:\Program Files\PuTTY`
- Restart PowerShell/Terminal

### Connection fails
1. Test plink directly:
   ```powershell
   plink.exe -ssh jumpuser@bastion.example.com
   ```

2. Accept host key if prompted

3. Test proxy connection:
   ```powershell
   plink.exe -batch -ssh -pw "password" jumpuser@bastion -nc device.internal:22
   ```

### Password with special characters
- Use double quotes in PowerShell
- Escape with backtick: `` ` ``
- Example: ``--password "pass`$word"``

## Expected Behavior

### Before v0.7.4 (Windows)
- ❌ Bastion password auth fails (prompts for password)
- ✅ Direct connections work
- ✅ Bastion with SSH keys works

### After v0.7.4 (Windows with plink.exe)
- ✅ Bastion password auth works automatically
- ✅ Direct connections work
- ✅ Bastion with SSH keys works
- ✅ Falls back to standard SSH if plink not available

## Reporting Results

Please report your test results:

1. Windows version
2. Ruby version (`ruby -v`)
3. PuTTY/plink version (`plink -V`)
4. Test script output
5. Any errors or issues

Create an issue at: https://github.com/mitre/train-juniper/issues
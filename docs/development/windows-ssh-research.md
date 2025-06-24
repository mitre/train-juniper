# Windows SSH Authentication Research

This document captures the research and decision-making process behind implementing Windows bastion password authentication support in train-juniper.

## The Problem

Windows OpenSSH doesn't properly support the SSH_ASKPASS environment variable for automated password authentication. This affects bastion/jump host connections where passwords are required.

## Root Cause Analysis

### Windows OpenSSH Behavior
- Requires no terminal association for SSH_ASKPASS to work
- Different versions have different behavior (worse in newer versions)
- GitHub Issue: [PowerShell/Win32-OpenSSH#2115](https://github.com/PowerShell/Win32-OpenSSH/issues/2115)

### Net::SSH Implementation
- Net::SSH::Proxy::Jump builds SSH command: `ssh -J jump_host target`
- Relies on system SSH client for execution
- No way to inject password into the proxy connection programmatically

## Solutions Investigated

### 1. SSH_ASKPASS Script (Initial Implementation)
**Status**: Doesn't work reliably on Windows

We initially implemented SSH_ASKPASS support by creating platform-specific scripts:
- PowerShell script + batch wrapper for Windows
- Bash script for Unix-like systems

**Issue**: Windows OpenSSH ignores SSH_ASKPASS in most configurations

### 2. Using plink.exe (PuTTY) - CHOSEN SOLUTION
**Status**: Implemented in v0.7.4

**Advantages**:
- Supports `-pw` flag for password authentication
- Widely available on Windows (comes with PuTTY)
- Used successfully by other Ruby projects (e.g., hglib.rb)
- No terminal/TTY complications

**Implementation**: Detect plink.exe availability and automatically use it instead of SSH when:
- Running on Windows
- Password authentication is required
- plink.exe is available in PATH

### 3. Direct Net::SSH Connection Chain
**Status**: Not implemented (too complex)

This would involve creating a direct Net::SSH connection to the bastion, then tunneling through it to reach the target device. While technically possible, it would:
- Require significant refactoring
- Bypass Net::SSH::Proxy entirely
- Create maintenance burden

## Implementation Details

The solution uses a modular approach with three components:

1. **WindowsProxy** module - Handles plink.exe detection and command building
2. **SshAskpass** module - Maintains SSH_ASKPASS support for non-Windows platforms
3. **BastionProxy** module - Orchestrates proxy selection based on platform and availability

## Security Considerations

### Host Key Verification
plink.exe requires manual host key acceptance on first connection. We document this requirement rather than auto-accepting to maintain security.

### Password Handling
Passwords are passed via command-line arguments to plink.exe. While this has security implications (visible in process listings), it's the standard approach used by plink and accepted in the Windows ecosystem.

## Future Improvements

1. **Auto Host Key Management**: Could add optional host key fingerprint configuration
2. **Credential Storage**: Could integrate with Windows Credential Manager
3. **Alternative Tools**: Could support other SSH clients like KiTTY's klink.exe

## References

- [Net::SSH::Proxy documentation](https://github.com/net-ssh/net-ssh)
- [PuTTY plink documentation](https://www.putty.org/docs.html)
- [Windows OpenSSH known issues](https://github.com/PowerShell/Win32-OpenSSH/issues)
- [hglib.rb plink implementation](https://github.com/dgutov/hglib) - Prior art for plink.exe usage
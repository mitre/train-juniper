# Windows Bastion Authentication Setup

This guide helps Windows users configure bastion/jump host authentication with the train-juniper plugin.

!!! tip "Prerequisites"
    Make sure you have Ruby properly installed on Windows. See the [Windows Ruby Setup Guide](windows-setup.md) for detailed instructions on setting up Ruby, InSpec, and development tools.

## Installation

### Via RubyGems (Recommended)
```powershell
gem install train-juniper
```

### Via InSpec Plugin (Alternative)
If `inspec plugin install train-juniper` fails with "Unknown error occurred", use the direct gem install method above. This is a known InSpec issue on some Windows installations.

## Bastion/Jump Host Authentication

### SSH Key Authentication (Recommended)
For best results on Windows, use SSH key authentication for bastion hosts:

```ruby
# Example with SSH key
conn = Train.create('juniper', {
  host: 'device.example.com',
  user: 'admin',
  bastion_host: 'bastion.example.com',
  bastion_user: 'jumpuser',
  key_files: ['~/.ssh/id_rsa']  # Works for both device and bastion
})
```

### Password Authentication with PuTTY's plink.exe

Windows OpenSSH doesn't support the SSH_ASKPASS environment variable, which prevents automated password authentication through bastion hosts. The train-juniper plugin automatically uses PuTTY's `plink.exe` when available to work around this limitation.

!!! info "Community Pattern"
    This approach follows established patterns used by Ruby projects like hglib (Mercurial) and others that need Windows SSH proxy support. The implementation uses `Net::SSH::Proxy::Command` with plink.exe.

#### Installing PuTTY
1. Download PuTTY from: https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html
2. Install PuTTY or extract the standalone executables
3. Add PuTTY's directory to your system PATH:
   - Open System Properties → Advanced → Environment Variables
   - Add PuTTY's directory (e.g., `C:\Program Files\PuTTY`) to PATH

#### Verify plink.exe is Available
```powershell
where plink.exe
```

#### Accept Bastion Host Key (One-time Setup)
Before using password authentication with a bastion host, you must accept the bastion's SSH host key:

```powershell
# Replace with your actual bastion host and username
plink.exe -ssh your-username@your-bastion-host.com

# You'll see a message like:
# "The host key is not cached. You have no guarantee that the server 
# is the computer you think it is... Store key in cache? (y/n)"

# Type 'y' and press Enter to accept the host key
# Then exit the connection (type 'exit' or press Ctrl+C)
```

!!! warning "Security Note"
    Only accept the host key if you're certain you're connecting to the correct bastion host. This is a one-time setup per bastion host.

#### Using Password Authentication
When plink.exe is available, password authentication works automatically:

```ruby
conn = Train.create('juniper', {
  host: 'device.example.com',
  user: 'admin',
  password: 'device_password',
  bastion_host: 'bastion.example.com',
  bastion_user: 'jumpuser',
  bastion_password: 'bastion_password'  # Works with plink.exe
})
```

### Troubleshooting

#### Password Prompt Still Appears
If you're still prompted for passwords:
1. Verify plink.exe is in your PATH: `where plink.exe`
2. Ensure you've accepted the bastion host key (see setup steps above)
3. Check if plink is being detected by enabling debug logging
4. Consider using SSH keys instead

#### Connection Failures
1. Test direct SSH connection first: `ssh user@host`
2. Test plink connection to bastion:
   ```powershell
   plink.exe -ssh jumpuser@bastion.example.com
   ```
3. Test plink proxy connection:
   ```powershell
   plink.exe -batch -ssh -pw "password" jumpuser@bastion -nc device.internal:22
   ```
4. Enable debug logging to see which proxy method is being used:
   ```powershell
   $env:TRAIN_JUNIPER_LOG_LEVEL = "debug"
   inspec shell -t juniper://admin@device --password 'pass' `
     --bastion-host jump --bastion-user user `
     --bastion-password 'bastion-pass' -l debug
   ```
   Look for: "Using plink.exe for bastion proxy"

#### Password with Special Characters
- Use double quotes in PowerShell
- Escape with backtick: `` ` ``
- Example: ``--password "pass`$word"``

#### Debugging plink.exe Detection
Enable debug logging to verify plink.exe is being used:
```ruby
conn = Train.create('juniper', {
  host: 'device.example.com',
  bastion_host: 'jump.example.com',
  logger: Logger.new(STDOUT, level: :debug)
})
```

Debug messages to look for:
- "Using plink.exe for bastion proxy" - plink is being used
- "Using bastion host: ..." - standard SSH proxy (plink not detected)

## InSpec Usage on Windows

### Testing with InSpec Shell
After accepting the bastion host key, test your connection:

```powershell
# Test connection with InSpec shell
inspec shell -t juniper://admin@device.example.com --password 'device-password' `
  --bastion-host bastion.example.com `
  --bastion-user jumpuser `
  --bastion-password 'bastion-password'

# Once connected, you can run commands:
# juniper.version
# juniper.model
# command('show version').stdout
```

### Running InSpec Profiles

```powershell
# Using train-juniper with InSpec
inspec exec profile --target juniper://admin@device.example.com --password 'secret'

# With bastion host (SSH keys recommended)
inspec exec profile --target juniper://admin@device.example.com `
  --bastion-host bastion.example.com `
  --bastion-user jumpuser
```

## Known Limitations

1. **SSH_ASKPASS**: Not supported by Windows OpenSSH
2. **InSpec Plugin Installer**: May fail on some Windows installations - use `gem install` instead
3. **Password with Special Characters**: May need escaping in PowerShell

## Security Recommendations

1. Use SSH keys whenever possible
2. Store credentials in environment variables or credential managers
3. Avoid hardcoding passwords in scripts
4. Use Windows Credential Manager for secure storage
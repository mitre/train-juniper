# Ruby, InSpec, and Terminal Customization Setup Guide (Windows)

!!! info "Windows Development Environment"
    This guide provides a comprehensive setup for Ruby and InSpec development on Windows, including modern terminal customization for an enhanced developer experience.

## 1. Ruby Version Management

!!! recommendation "Recommended Tools"
    - **[RubyInstaller](https://rubyinstaller.org/downloads/)** - Official Ruby distribution for Windows
    - **[uru](https://bitbucket.org/jonforums/uru/downloads/)** - Lightweight Ruby version manager for Windows

### Installation Steps
  1. Download and install Ruby (with DevKit) from RubyInstaller.
  2. Install uru (via [Chocolatey](https://chocolatey.org/) or manual download):
     ```powershell
     choco install uru
     ```
  3. Register each Ruby version:
     ```powershell
     uru admin add C:\Ruby34-x64\bin
     ```
  4. Switch versions:
     ```powershell
     uru <label>
     ```
  5. List registered Rubies:
     ```powershell
     uru ls
     ```

!!! tip "Installing uru with Chocolatey"
    Chocolatey is the easiest way to install uru on Windows:
    
    ```powershell
    choco install uru
    ```
    
    While the [uru downloads page](https://bitbucket.org/jonforums/uru/downloads/) doesn't prominently mention this option, the [uru installation wiki](https://bitbucket.org/jonforums/uru/wiki/Install) provides comprehensive details.

---

## 2. Disable Gem Documentation (Faster Installs)

!!! tip "Speed up gem installations"
    Create or edit `%USERPROFILE%\.gemrc` to disable documentation generation:
    
    ```yaml
    gem: --no-document
    ```

---

## 3. Install InSpec and Related Gems

```powershell
gem install inspec inspec-bin inspec-core --no-document
```

---

## 4. Terminal Customization

!!! success "Modern Terminal Stack"
    Transform your Windows terminal into a powerful, beautiful development environment:

### Essential Components

=== "Windows Terminal"
    Install from [Microsoft Store](https://aka.ms/terminal) for a modern, GPU-accelerated terminal experience.

=== "PowerShell 7+"
    Install via [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/) or [Chocolatey](https://chocolatey.org/):
    ```powershell
    winget install Microsoft.PowerShell
    # or
    choco install powershell-core
    ```

### Prompt Customization  
  - Oh My Posh:
    ```powershell
    winget install JanDeDobbeleer.OhMyPosh
    oh-my-posh init pwsh --config "$(oh-my-posh get shell-path pwsh)" | Invoke-Expression
    ```
  - Starship:
    ```powershell
    winget install Starship.Starship
    echo 'Invoke-Expression (&starship init powershell)' >> $PROFILE
    ```
!!! important "Nerd Fonts Required"
    Download and install a [Nerd Font](https://www.nerdfonts.com/) for proper icon display in your customized prompt. Popular choices include:
    
    - FiraCode Nerd Font
    - Meslo Nerd Font
    - JetBrains Mono Nerd Font

---

## 5. Troubleshooting & Tips

!!! warning "Common Issues and Solutions"

- **Path Issues:** Ensure Ruby's `bin` directory is in your PATH.
- **Permissions:** Run terminals as a regular user unless you need admin rights.
- **Native Gem Builds:** May be slow on Windows VMs/Citrix; be patient.
- **Switching Rubies:** Use `uru` to change Ruby versions as needed.
??? bug "Multiple Gem Versions"
    Check for multiple versions:
    ```powershell
    gem list inspec
    gem list ffi
    ```
    
    Uninstall old/conflicting versions:
    ```powershell
    gem uninstall inspec
    gem uninstall ffi
    ```

??? tip "Ruby Version Activation"
    Always activate the correct Ruby version with `uru <label>` before installing or running gems.

??? example "Removing Directories"
    Use PowerShell to remove directories:
    ```powershell
    Remove-Item -Recurse -Force <directory>
    ```

??? warning "SSL/Certificate Issues"
    If you encounter SSL errors with `gem` or `ruby`:
    
    1. Ensure your system certificates are up to date
    2. For organizational CAs, add the certificate to Windows certificate store:
       ```powershell
       [System.Environment]::SetEnvironmentVariable("SSL_CERT_FILE", 
           "C:\\path\\to\\your\\ca-bundle.crt", 
           [System.EnvironmentVariableTarget]::User)
       ```
    3. Update Ruby's certificate bundle if needed - see [Ruby SSL Troubleshooting](https://www.ruby-lang.org/en/news/2014/12/09/do-not-use-openssl-1-0-1k/)

??? bug "FFI Troubleshooting"
    If you see ffi errors:
    
    1. Install with platform flag:
       ```powershell
       gem install ffi --platform=ruby
       ```
    2. Ensure you have a compatible Ruby and DevKit/MSYS2 environment

---

## 6. VS Code Setup

!!! recommendation "Enhanced Development Experience"

- Install [VS Code](https://code.visualstudio.com/).
- Recommended extensions:
  - Ruby
  - Solargraph
  - VSCode Ruby
  - Test Explorer UI
  - PowerShell (for Windows)
- Configure your terminal in VS Code to use Windows Terminal or PowerShell as preferred.

---

## 7. Resources

| Resource | Description | Link |
|----------|-------------|------|
| **RubyInstaller** | Official Ruby distribution for Windows | [rubyinstaller.org](https://rubyinstaller.org/) |
| **uru** | Lightweight Ruby version manager | [bitbucket.org/jonforums/uru](https://bitbucket.org/jonforums/uru/) |
| **InSpec** | Infrastructure testing framework | [inspec.io](https://www.inspec.io/) |
| **Oh My Posh** | Prompt theme engine for any shell | [ohmyposh.dev](https://ohmyposh.dev/) |
| **Starship** | Cross-shell prompt | [starship.rs](https://starship.rs/) |
| **Nerd Fonts** | Patched fonts with icons | [nerdfonts.com](https://www.nerdfonts.com/) |

---

## 8. Additional Best Practices & FAQ

### Environment Isolation

!!! best-practice "Project Isolation with Bundler"
- Use Bundler and a `Gemfile` for project-specific dependencies:
  ```ruby
  # Gemfile
  source 'https://rubygems.org'
  gem 'inspec', '~> 6.0'
  ```
  Then run:
  ```powershell
  gem install bundler
  bundle install
  ```
- This helps avoid global gem conflicts and ensures consistent environments.

### Automated Setup Script

!!! idea "Automation Opportunity"
    Consider creating a PowerShell script to automate the setup process for new team members, including Ruby installation, uru configuration, and gem setup.

### Checking Ruby & Gem Health
- Verify your environment:
  ```powershell
  ruby -v
  gem -v
  gem env
  where inspec
  ```

### Proxy/Firewall/Corporate Network Issues
- If your organization uses a proxy, set these environment variables:
  ```powershell
  [System.Environment]::SetEnvironmentVariable("HTTP_PROXY", "http://proxy.example.com:8080", [System.EnvironmentVariableTarget]::User)
  [System.Environment]::SetEnvironmentVariable("HTTPS_PROXY", "http://proxy.example.com:8080", [System.EnvironmentVariableTarget]::User)
  ```

### Windows Defender/Antivirus
- Some antivirus or Defender settings may block Ruby or gem executables. If you encounter issues, whitelist the Ruby install directory.

### Sample PowerShell Profile
- Add this to your `$PROFILE` to auto-activate a Ruby version and set up your prompt:
  ```powershell
  # Auto-activate Ruby version with uru
  uru 344  # or your preferred label
  # Optional: initialize Oh My Posh or Starship
  oh-my-posh init pwsh --config "$(oh-my-posh get shell-path pwsh)" | Invoke-Expression
  # or
  Invoke-Expression (&starship init powershell)
  ```

### Frequently Asked Questions

!!! question "FAQ"
- **Why do I get SSL errors?**
  - Your system or Ruby certificates may be out of date. See the SSL/Certificate Issues section above.
- **How do I fix ffi build errors?**
  - Ensure you have the correct DevKit/MSYS2 installed and try `gem install ffi --platform=ruby`.
- **How do I clean up old Ruby or gem versions?**
  - Use `uru admin rm <label>` to remove old Rubies, and `gem uninstall <gemname>` to remove old gems.
- **How do I check which Ruby or gem is active?**
  - Run `ruby -v`, `gem env`, and `where inspec` to verify your environment.

---

## 9. Referenced Sources & Validation Summary

### Official Documentation & References
- [RubyInstaller for Windows](https://rubyinstaller.org/)
- [uru Ruby Version Manager](https://bitbucket.org/jonforums/uru/)
  - [uru Installation Wiki](https://bitbucket.org/jonforums/uru/wiki/Install)
- [InSpec](https://www.inspec.io/)
- [RubyGems](https://guides.rubygems.org/)
- [Bundler](https://bundler.io/)
- [Oh My Posh](https://ohmyposh.dev/)
- [Starship Prompt](https://starship.rs/)
- [Nerd Fonts](https://www.nerdfonts.com/)
- [Windows Terminal](https://aka.ms/terminal)
- [PowerShell](https://learn.microsoft.com/en-us/powershell/)
- [Chocolatey](https://chocolatey.org/)
- [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/)
- [VS Code](https://code.visualstudio.com/)
- [Ruby SSL Troubleshooting](https://www.ruby-lang.org/en/news/2014/12/09/do-not-use-openssl-1-0-1k/)

---

Feel free to share this guide with your team or adapt it for your organization!
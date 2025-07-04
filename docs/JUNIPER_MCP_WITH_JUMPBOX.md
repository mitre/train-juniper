# Juniper MCP Server with Jump Box Configuration

## The Challenge
Your Juniper device is behind a jump box (bastion host), which means:
- No direct SSH connection from your local machine
- Need to proxy through the jump box
- Standard MCP Docker setup won't work directly

## Solution Options

### Option 1: SSH ProxyJump Configuration (Recommended)

First, set up your SSH config to handle the jump automatically:

```bash
# ~/.ssh/config
Host jumpbox
    HostName JUMPBOX_IP
    User JUMPBOX_USER
    Port 22

Host juniper
    HostName JUNIPER_INTERNAL_IP
    User JUNIPER_USER
    Port 22
    ProxyJump jumpbox
```

Then modify the MCP server to use the SSH config:

```json
{
  "mcpServers": {
    "juniper": {
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-i",
        "-v", "${HOME}/.ssh:/root/.ssh:ro",
        "junos-mcp-server"
      ],
      "env": {
        "JUNOS_HOSTNAME": "juniper",  // Uses SSH config alias
        "JUNOS_USERNAME": "YOUR_USERNAME",
        "JUNOS_PASSWORD": "YOUR_PASSWORD"
      }
    }
  }
}
```

### Option 2: SSH Tunnel Approach

Create a tunnel through the jump box:

```bash
# Terminal 1: Create tunnel
ssh -L 2222:JUNIPER_INTERNAL_IP:22 JUMPBOX_USER@JUMPBOX_IP -N

# Now localhost:2222 forwards to Juniper device
```

MCP configuration:
```json
{
  "mcpServers": {
    "juniper": {
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-i",
        "--network", "host",
        "junos-mcp-server"
      ],
      "env": {
        "JUNOS_HOSTNAME": "localhost",
        "JUNOS_PORT": "2222",
        "JUNOS_USERNAME": "YOUR_USERNAME",
        "JUNOS_PASSWORD": "YOUR_PASSWORD"
      }
    }
  }
}
```

### Option 3: Alternative - Direct Collection Script

Since MCP might be complex with a jump box, consider a simpler approach:

```ruby
#!/usr/bin/env ruby
# collect_via_jumpbox.rb

require 'net/ssh'
require 'net/ssh/proxy/jump'

# Configure jump box proxy
proxy = Net::SSH::Proxy::Jump.new('JUMPBOX_USER@JUMPBOX_IP')

# Connect to Juniper through jump box
Net::SSH.start('JUNIPER_INTERNAL_IP', 'JUNIPER_USER', 
               password: 'JUNIPER_PASSWORD',
               proxy: proxy) do |ssh|
  
  # Read-only commands to discover states
  commands = [
    'show configuration | display xml | match disable',
    'show configuration | display xml | match inactive',
    'show configuration system services | display xml',
    'show configuration snmp | display xml'
  ]
  
  commands.each do |cmd|
    puts "Running: #{cmd}"
    output = ssh.exec!(cmd)
    # Save output to file
    filename = cmd.gsub(/[^\w]/, '_') + '.xml'
    File.write("fixtures/#{filename}", output)
  end
end
```

### Option 4: Use Existing train-juniper Connection

Since train-juniper already handles the jump box connection, we could extend it:

```ruby
# In train-juniper context
require 'train'

conn = Train.create('juniper', {
  host: 'JUNIPER_IP',
  user: 'USER',
  password: 'PASS',
  proxy_command: 'ssh -W %h:%p JUMPBOX_USER@JUMPBOX_IP'
})

# Use connection to collect fixtures
result = conn.run_command('show configuration snmp | display xml')
File.write('snmp_fixture.xml', result.stdout)
```

## Recommendation

Given the jump box complexity, I recommend:

1. **For immediate needs**: Use Option 4 (train-juniper with collection script)
2. **For future MCP**: Set up Option 1 (SSH ProxyJump config)

The train-juniper approach leverages your existing working connection and avoids MCP complexity.

## Quick Collection Script

Here's a simple script using your existing setup:

```bash
#!/bin/bash
# collect_states.sh

# Commands to collect different states
COMMANDS=(
  "show configuration | display xml | match disable"
  "show configuration | display xml | match inactive" 
  "show configuration system services | display xml"
  "show configuration snmp | display xml"
  "show configuration system login | display xml"
)

for cmd in "${COMMANDS[@]}"; do
  echo "Collecting: $cmd"
  # Use your existing SSH command with jump box
  ssh -J JUMPBOX_USER@JUMPBOX_IP JUNIPER_USER@JUNIPER_IP "$cmd" > "fixture_$(echo $cmd | tr ' /' '__').xml"
done
```

This avoids MCP complexity while still getting the fixture data we need!
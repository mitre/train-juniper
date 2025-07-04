# Setting Up Juniper MCP Server for Claude Code

## Prerequisites
- Docker installed on your system
- SSH access to your Juniper device
- Claude Desktop app

## Step 1: Clone and Build the MCP Server

```bash
# Clone the repository
git clone https://github.com/Juniper/junos-mcp-server.git
cd junos-mcp-server

# Build the Docker image
docker build -t junos-mcp-server .
```

## Step 2: Configure Claude Desktop

Add the MCP server to your Claude Desktop configuration file:

### macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
### Windows: `%APPDATA%\Claude\claude_desktop_config.json`
### Linux: `~/.config/Claude/claude_desktop_config.json`

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
        "JUNOS_HOSTNAME": "YOUR_JUNIPER_IP",
        "JUNOS_USERNAME": "YOUR_USERNAME",
        "JUNOS_PASSWORD": "YOUR_PASSWORD",
        "JUNOS_PORT": "22"
      }
    }
  }
}
```

## Step 3: Alternative - Using Password from File (More Secure)

Create a password file:
```bash
echo "your_password" > ~/.juniper_password
chmod 600 ~/.juniper_password
```

Update the config to read from file:
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
        "-v", "${HOME}/.juniper_password:/tmp/password:ro",
        "junos-mcp-server"
      ],
      "env": {
        "JUNOS_HOSTNAME": "YOUR_JUNIPER_IP",
        "JUNOS_USERNAME": "YOUR_USERNAME",
        "JUNOS_PASSWORD_FILE": "/tmp/password",
        "JUNOS_PORT": "22"
      }
    }
  }
}
```

## Step 4: Test the Connection

1. Restart Claude Desktop after updating the config
2. In Claude, you should see the MCP connection indicator
3. Try a simple command to test:

```
Can you check if the Juniper MCP server is connected and show me the device version?
```

## Step 5: Using MCP for State Collection

Once connected, Claude Code can:

### Safely Query Device State
```
Show me the current SNMP configuration including any disabled features
```

### Collect Multiple Configurations
```
Please collect the following configurations:
1. SNMP configuration (including if disabled)
2. System services (showing which are enabled/disabled)
3. User configuration (including any inactive users)
4. Interface status (including disabled interfaces)
```

### Generate Fixtures
```
Based on the collected configurations, create test fixtures showing:
1. SNMP in disabled state
2. Services with only SSH enabled
3. Users with some marked as inactive
```

## Security Considerations

1. **Read-Only Access**: Configure a read-only user on the Juniper device:
```junos
set system login user mcp-readonly class read-only
set system login user mcp-readonly authentication plain-text-password
```

2. **Network Security**: 
   - Use `--network host` only if needed
   - Consider using a specific Docker network
   - Restrict access to the MCP server

3. **Credential Management**:
   - Never commit passwords to git
   - Use environment variables or files
   - Rotate credentials regularly

## Troubleshooting

### Connection Issues
- Check Docker logs: `docker logs <container_id>`
- Verify network connectivity to Juniper device
- Ensure SSH is enabled on the device

### MCP Not Showing in Claude
- Restart Claude Desktop
- Check config file syntax (valid JSON)
- Look for errors in Claude's developer console

### Permission Denied
- Ensure Docker daemon is running
- User has permission to run Docker
- Password file has correct permissions (600)

## Example Session with Claude Code

Once set up, you can ask Claude Code to:

1. **Discover States**: "What disabled or inactive features are currently configured on the device?"

2. **Collect Fixtures**: "Please collect XML output for all system services, highlighting which are enabled vs disabled"

3. **Validate Assumptions**: "Can you verify if SNMP can have a <disable/> element in its configuration?"

4. **Generate Test Data**: "Based on the real device output, create fixture files for our state testing scenarios"

This provides a safe, controlled way to interact with the Juniper device without making any configuration changes.
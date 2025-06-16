# Train Plugin URI Design Patterns

Understanding how to design connection URIs is critical for creating intuitive, enterprise-ready Train plugins. Different target systems and user communities expect different URI patterns.

## Table of Contents

1. [URI Fundamentals](#uri-fundamentals)
2. [SSH-Style URIs (Network Infrastructure)](#ssh-style-uris-network-infrastructure)
3. [API-Style URIs (Web Services)](#api-style-uris-web-services)
4. [Cloud-Style URIs (Resource Identifiers)](#cloud-style-uris-resource-identifiers)
5. [Container-Style URIs (Virtualized Resources)](#container-style-uris-virtualized-resources)
6. [Protocol-Style URIs (Specialized Systems)](#protocol-style-uris-specialized-systems)
7. [Choosing the Right Pattern](#choosing-the-right-pattern)
8. [Implementation Guidelines](#implementation-guidelines)

---

## URI Fundamentals

### How Train Parses URIs

When users run `inspec detect -t "transport://user@host?option=value"`, Train:

1. **Parses the URI** using Ruby's URI library
2. **Extracts components** (scheme, user, host, port, path, query)
3. **Converts to options hash** with string keys and values
4. **Passes to your Transport** via Train.create()
5. **Your Transport** receives options in connection() method

### Standard URI Structure

```
transport://[user[:password]@]host[:port][/path][?param1=value1&param2=value2]
```

**Components:**
- **scheme**: Your plugin name (must match `name` in Transport)
- **user**: Username for authentication
- **password**: Password (not recommended in URI)  
- **host**: Primary identifier (hostname, IP, resource ID)
- **port**: Network port number
- **path**: Hierarchical resource path
- **query**: Additional parameters as key=value pairs

### Critical Rule: URI Parameters Are Strings

```ruby
# URI: transport://user@host:22?timeout=30&ssl=true
# Train parses as:
{
  "backend" => "transport",
  "user" => "user",
  "host" => "host", 
  "port" => "22",        # String, not integer!
  "timeout" => "30",     # String, not integer!
  "ssl" => "true"        # String, not boolean!
}
```

**Handle in your Connection initialize():**
```ruby
def initialize(options)
  @options = options.dup
  
  # Convert string parameters to correct types
  @options[:port] = @options[:port].to_i if @options[:port]
  @options[:timeout] = @options[:timeout].to_i if @options[:timeout]
  @options[:ssl] = @options[:ssl] == 'true' if @options.key?(:ssl)
end
```

---

## SSH-Style URIs (Network Infrastructure)

**Best for**: Network devices, servers, traditional infrastructure

**Pattern**: `transport://[user@]host[:port]`

**Target Audience**: Network engineers, system administrators

### Examples

```bash
# Basic network device
juniper://admin@192.168.1.1

# Custom SSH port
juniper://admin@switch.corp.com:2222

# With bastion host (enterprise pattern)
juniper://admin@internal.switch?bastion_host=jump.corp.com&bastion_user=netops

# Environment variables
export JUNIPER_HOST=device.corp
export JUNIPER_USER=admin
inspec detect -t juniper://
```

### Transport Options Definition

```ruby
class Transport < Train.plugin(1)
  name "juniper"
  
  # Primary connection options
  option :host, required: true
  option :port, default: 22
  option :user, required: true
  option :password, default: nil
  option :timeout, default: 30
  
  # Enterprise proxy options (Train standard)
  option :bastion_host, default: nil
  option :bastion_user, default: "root"
  option :bastion_port, default: 22
  option :proxy_command, default: nil
  
  # SSH authentication options
  option :key_files, default: nil
  option :keys_only, default: false
  option :keepalive, default: true
  option :keepalive_interval, default: 60
end
```

### Real-World Enterprise Patterns

```bash
# DMZ access through corporate jump host
inspec exec profile -t "juniper://netops@firewall.dmz?bastion_host=jump.corp&bastion_user=svc_inspec"

# Multi-environment with different jump hosts
inspec detect -t "juniper://admin@prod-core-01?bastion_host=prod-jump.corp&bastion_port=2222"
inspec detect -t "juniper://admin@dev-core-01?bastion_host=dev-jump.corp&bastion_port=2222"

# SSH key authentication through bastion
inspec shell -t "juniper://automation@secure-switch?bastion_host=secure-jump&key_files=/path/to/key"
```

### Other Network Transport Examples

```bash
# Cisco IOS devices
cisco-ios://admin@catalyst-switch:22

# Serial console connections  
serial:///dev/ttyUSB0?baud=9600&timeout=10

# Telnet (legacy network equipment)
telnet://admin@legacy-router:23?login_prompt=Username:%20&password_prompt=Password:%20
```

---

## API-Style URIs (Web Services)

**Best for**: REST APIs, web services, HTTP-based systems

**Pattern**: `transport://api.domain.com[/version][?auth_params]`

**Target Audience**: API developers, DevOps engineers, web developers

### Examples

```bash
# Basic REST API
rest://api.example.com/v1/

# With API key authentication  
rest://api.company.com/v2/?auth_type=header&apikey=abc123&header=X-API-Key

# Bearer token authentication
rest://secure-api.corp?auth_type=bearer&token=eyJhbGc...

# AWS API with SigV4 authentication
rest://ec2.us-west-2.amazonaws.com/?auth_type=awsv4&region=us-west-2
```

### Transport Options Definition

```ruby
class Transport < Train.plugin(1)
  name "rest"
  
  # API endpoint configuration
  option :endpoint, required: true
  option :verify_ssl, default: true
  option :timeout, default: 120
  option :headers, default: {}
  
  # Authentication options
  option :auth_type, default: :anonymous
  option :username, default: nil
  option :password, default: nil
  option :token, default: nil
  option :apikey, default: nil
  option :header, default: "X-API-Key"
  
  # Advanced options
  option :proxy, default: nil
  option :follow_redirects, default: true
  option :max_redirects, default: 3
end
```

### Authentication Patterns

```ruby
# In connection.rb
def setup_authentication
  case @options[:auth_type]
  when :basic
    @auth_header = basic_auth_header
  when :bearer
    @auth_header = bearer_token_header  
  when :header
    @custom_headers[@options[:header]] = @options[:apikey]
  when :awsv4
    @auth_strategy = :aws_signature_v4
  end
end
```

### Real-World API Examples

```bash
# Kubernetes API server
rest://k8s-api.corp.com:6443/api/v1/?auth_type=bearer&token=eyJhbGc...

# GitLab API
rest://gitlab.company.com/api/v4/?auth_type=header&apikey=glpat-xxx&header=PRIVATE-TOKEN

# Custom application API
rest://monitoring.internal/api/v2/?auth_type=basic&username=inspec&password=secret

# Cloud provider APIs
rest://management.azure.com/?auth_type=bearer&token=access_token
```

---

## Cloud-Style URIs (Resource Identifiers)

**Best for**: Cloud resources, managed services, virtual infrastructure

**Pattern**: `transport://resource-id[/sub-resource]`

**Target Audience**: Cloud engineers, DevOps teams, infrastructure automation

### Examples

```bash
# AWS EC2 instance via Systems Manager
awsssm://i-1234567890abcdef0

# Azure virtual machine
azure://subscription-123/vm-456

# Google Cloud instance
gcp://project-id/instance-name

# Kubernetes pod
k8s://namespace/pod-name
```

### AWS Systems Manager Pattern

```ruby
class Transport < Train.plugin(1)
  name "awsssm"
  
  # AWS resource identification
  option :host, required: true  # EC2 instance ID or private IP
  option :mode, default: "run-command"
  option :execution_timeout, default: 60.0
  
  # AWS authentication (via environment/IAM)
  option :region, default: ENV["AWS_REGION"] || "us-east-1"
  option :profile, default: ENV["AWS_PROFILE"]
  option :access_key, default: ENV["AWS_ACCESS_KEY_ID"]
  option :secret_key, default: ENV["AWS_SECRET_ACCESS_KEY"]
  option :session_token, default: ENV["AWS_SESSION_TOKEN"]
end
```

### Azure Resource Pattern

```ruby
class Transport < Train.plugin(1)
  name "azure"
  
  # Azure resource identification
  option :subscription_id, default: ENV["AZURE_SUBSCRIPTION_ID"]
  option :resource_group, default: nil
  option :vm_name, default: nil
  
  # Azure authentication
  option :tenant_id, default: ENV["AZURE_TENANT_ID"]
  option :client_id, default: ENV["AZURE_CLIENT_ID"] 
  option :client_secret, default: ENV["AZURE_CLIENT_SECRET"]
  option :credentials_file, default: ENV["AZURE_CRED_FILE"]
end
```

### Cloud URI Construction

```ruby
# In connection.rb
def uri
  case @options[:cloud_provider]
  when :aws
    "awsssm://#{@instance_id}"
  when :azure
    "azure://#{@subscription_id}/#{@resource_group}/#{@vm_name}"
  when :gcp
    "gcp://#{@project_id}/#{@zone}/#{@instance_name}"
  end
end
```

### Real-World Cloud Examples

```bash
# Multi-region AWS deployment
awsssm://i-prod-web-01  # defaults to AWS_REGION
AWS_REGION=us-west-2 awsssm://i-prod-web-02

# Azure development vs production
azure://dev-subscription/webservers/web-01
azure://prod-subscription/webservers/web-01

# GCP with project switching
gcp://dev-project/us-central1-a/web-instance
gcp://prod-project/us-east1-b/web-instance
```

---

## Container-Style URIs (Virtualized Resources)

**Best for**: Containers, pods, virtualized workloads

**Pattern**: `transport://[namespace/]container[/sub-resource]`

**Target Audience**: Container platform users, Kubernetes operators, DevOps teams

### Examples

```bash
# Docker container
docker://nginx-container

# Podman container  
podman://web-app

# Kubernetes pod with namespace
k8s-container://production/web-deployment-abc123/nginx

# Kubernetes default namespace
k8s-container:///api-service-xyz/app
```

### Kubernetes Container Pattern

```ruby
class Transport < Train.plugin(1)
  name "k8s-container"
  
  # Kubernetes resource identification
  option :pod, default: nil
  option :container_name, default: nil
  option :namespace, default: "default"
  
  # Kubernetes authentication
  option :kubeconfig, default: ENV["KUBECONFIG"] || "~/.kube/config"
  option :context, default: nil
  option :cluster, default: nil
  
  # Connection options
  option :shell, default: "/bin/sh"
  option :command_timeout, default: 60
end
```

### Container URI Parsing

```ruby
# In connection.rb initialize()
def parse_container_uri
  # URI: k8s-container://namespace/pod/container
  uri_path = @options[:path]&.gsub(%r{^/}, "")
  
  if uri_path
    parts = uri_path.split("/")
    @namespace = @options[:host] || "default"
    @pod = @options[:pod] || parts[0] 
    @container_name = @options[:container_name] || parts[1]
  else
    @namespace = @options[:namespace] || @options[:host] || "default"
    @pod = @options[:pod]
    @container_name = @options[:container_name]
  end
end
```

### Real-World Container Examples

```bash
# Production Kubernetes cluster
k8s-container://prod/web-app-deployment-xyz/nginx
k8s-container://prod/api-service-abc/app-container

# Development environment  
k8s-container://dev/test-pod/debug-container

# Docker Compose services
docker://myapp_web_1
docker://myapp_db_1  

# Podman pods
podman://webapp-pod/nginx
podman://webapp-pod/php-fpm
```

---

## Protocol-Style URIs (Specialized Systems)

**Best for**: Hardware devices, specialized protocols, custom systems

**Pattern**: `transport://device-or-protocol-specific`

**Target Audience**: Hardware engineers, specialized system administrators

### Examples

```bash
# Serial device connections
serial:///dev/ttyUSB0?baud=9600&data_bits=8&parity=none

# VMware vSphere VMs
vsphere://vm-name?vcenter=vcenter.corp.com&username=admin

# Industrial control systems
modbus://192.168.1.100:502?unit_id=1&timeout=5

# Network attached storage
nfs://storage.corp.com/export/data
```

### Serial Device Pattern

```ruby
class Transport < Train.plugin(1)
  name "serial"
  
  # Serial device configuration
  option :device, default: "/dev/ttyUSB0"
  option :baud, default: 9600
  option :data_bits, default: 8
  option :parity, default: :none
  option :stop_bits, default: 1
  option :flow_control, default: :none
  
  # Protocol options
  option :timeout, default: 30
  option :prompt_pattern, default: /[>#$]\s*$/
  option :login_prompt, default: "login:"
  option :password_prompt, default: "Password:"
end
```

### vSphere Pattern

```ruby
class Transport < Train.plugin(1)
  name "vsphere"
  
  # vSphere connection
  option :vcenter_server, required: true, default: ENV["VI_SERVER"]
  option :vcenter_username, required: true, default: ENV["VI_USERNAME"] 
  option :vcenter_password, required: true, default: ENV["VI_PASSWORD"]
  
  # VM identification
  option :host, required: true  # VM name or identifier
  option :user, required: true  # Guest OS user
  option :password, required: true  # Guest OS password
  
  # Advanced options
  option :insecure, default: false
  option :datacenter, default: nil
  option :cluster, default: nil
end
```

---

## Choosing the Right Pattern

### Decision Matrix

| Target System | User Audience | Recommended Pattern | Example |
|---------------|---------------|-------------------|---------|
| Network devices, servers | Network/system admins | SSH-style | `juniper://admin@switch:22` |
| REST APIs, web services | Developers, DevOps | API-style | `rest://api.company.com/v1/` |
| Cloud resources | Cloud engineers | Cloud-style | `awsssm://i-instance-id` |
| Containers, pods | Container users | Container-style | `k8s://namespace/pod/container` |
| Hardware, specialized | Hardware engineers | Protocol-style | `serial:///dev/ttyUSB0` |

### Guidelines

1. **Match user expectations**: Choose patterns familiar to your target audience
2. **Follow existing conventions**: Use established patterns when possible
3. **Support hierarchical resources**: Use path components for sub-resources
4. **Enable authentication**: Support multiple auth methods appropriate for your system
5. **Consider enterprise needs**: Include proxy/bastion support for network isolation

---

## Implementation Guidelines

### 1. Define Transport Options

```ruby
class Transport < Train.plugin(1)
  name "yourname"
  
  # Every plugin should support these basic options
  option :host, required: true
  option :user, default: nil
  option :password, default: nil
  option :timeout, default: 30
  
  # Add pattern-specific options
  # SSH-style: port, bastion_host, key_files
  # API-style: endpoint, auth_type, headers
  # Cloud-style: region, subscription_id, project_id
  # Container-style: namespace, pod, container_name
end
```

### 2. Handle URI Parsing in Connection

```ruby
def initialize(options)
  @options = options.dup
  
  # Support environment variables
  @options[:host] ||= ENV['YOUR_HOST']
  @options[:user] ||= ENV['YOUR_USER']
  
  # Convert string URI parameters to correct types
  @options[:port] = @options[:port].to_i if @options[:port]
  @options[:timeout] = @options[:timeout].to_i if @options[:timeout]
  @options[:ssl] = @options[:ssl] == 'true' if @options.key?(:ssl)
  
  # Parse hierarchical URI components if needed
  parse_uri_components if uses_hierarchical_uris?
  
  super(@options)
end
```

### 3. Provide Clear URI Examples

Document all supported URI formats with real examples:

```ruby
# In your README.md
## Connection Examples

### Basic Connection
yourname://user@host

### With Authentication  
yourname://user@host?password=secret&timeout=60

### Enterprise Proxy
yourname://user@internal.host?bastion_host=jump.corp.com

### Environment Variables
export YOUR_HOST=device.corp
export YOUR_USER=admin
yourname://
```

### 4. Test URI Parsing

```ruby
# In test/integration/uri_parsing_test.rb
describe "URI parsing" do
  it "should parse basic URI components" do
    config = Train.target_config(target: "yourname://user@host:123")
    _(config[:backend]).must_equal("yourname")
    _(config[:user]).must_equal("user")
    _(config[:host]).must_equal("host")
    _(config[:port]).must_equal("123")  # String!
  end
  
  it "should parse query parameters" do
    uri = "yourname://user@host?timeout=60&ssl=true"
    config = Train.target_config(target: uri)
    _(config[:timeout]).must_equal("60")
    _(config[:ssl]).must_equal("true")
  end
end
```

### 5. Handle Edge Cases

```ruby
def initialize(options)
  # Handle missing required options
  validate_required_options
  
  # Handle conflicting options
  validate_option_conflicts
  
  # Provide helpful error messages
  rescue Train::ClientError => e
    raise Train::ClientError, "Invalid #{transport_name} URI: #{e.message}"
end

def validate_required_options
  if @options[:host].nil? || @options[:host].empty?
    raise Train::ClientError, "host is required for #{transport_name} connections"
  end
end
```

---

## Summary

Different Train plugin patterns serve different user communities and use cases:

- **SSH-style**: Familiar to network administrators, supports enterprise proxy patterns
- **API-style**: Natural for web developers, supports complex authentication
- **Cloud-style**: Matches cloud resource identifiers, integrates with cloud SDKs
- **Container-style**: Hierarchical naming for virtualized resources
- **Protocol-style**: Custom patterns for specialized hardware and protocols

Choose the pattern that best matches your target users' expectations and the nature of your target systems. When in doubt, SSH-style is the most universally understood pattern.

**Next**: Learn how to implement [Connection Implementation](05-connection-implementation.md) for your chosen URI pattern.
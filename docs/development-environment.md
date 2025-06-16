# Development Environment Setup for train-juniper

This document captures all research and setup instructions for developing and testing the train-juniper plugin.

## Overview

The train-juniper plugin uses **containerlab** + **vrnetlab** to provide authentic Juniper vSRX testing environments. This approach gives us real JunOS behavior for development and CI/CD testing.

## Technology Stack

### Core Components

1. **containerlab** (https://github.com/srl-labs/containerlab)
   - **Purpose**: "Lab-as-Code" orchestration tool for network topologies
   - **Role**: Creates and manages complex network labs using YAML topology files
   - **Analogy**: Like docker-compose but specifically designed for networking labs

2. **vrnetlab** (https://github.com/hellt/vrnetlab) 
   - **Purpose**: Converts VM-based network OS into Docker containers
   - **Role**: Packages Juniper vSRX (and other vendors) into containers
   - **Benefit**: Enables real network OS behavior within container environments

3. **Docker** 
   - **Role**: Container runtime used by containerlab
   - **Note**: containerlab manages Docker for you, but Docker is still the underlying engine

### How They Work Together

```
Developer -> containerlab -> Docker -> vrnetlab containers -> Real JunOS
            (orchestration)  (runtime)  (network OS)        (authentic behavior)
```

## macOS Development Setup

### Challenge: macOS Limitations

From containerlab documentation:
- **Limited ARM64 network OS images**: Most network devices are x86_64 only
- **Docker runs in Linux VM**: macOS Docker Desktop uses a Linux VM
- **Performance implications**: Emulation penalties for x86_64 images

### Recommended Approach

**Option 1: OrbStack (RECOMMENDED - Containerlab's preferred solution)**

OrbStack is a modern, high-performance Docker Desktop alternative specifically optimized for macOS, particularly Apple Silicon. The containerlab team specifically recommends OrbStack for macOS development.

**Why OrbStack for train-juniper:**
- ✅ **Containerlab official recommendation** - Mentioned in containerlab macOS docs
- ✅ **Native Linux machines** - Real Linux environment, not Docker Desktop's VM layer  
- ✅ **Superior performance** - "Lightning fast" startup, minimal resource usage
- ✅ **Better networking** - VPN and IPv6 support, more reliable for network containers
- ✅ **Drop-in replacement** - Uses same Docker commands, seamless migration

**Setup Process:**
```bash
# 1. Install OrbStack (replaces Docker Desktop)
brew install --cask orbstack

# 2. Create dedicated Linux machine for containerlab
orb create ubuntu:22.04 --name train-dev --arch arm64

# 3. Enter Linux machine
orb ssh train-dev

# 4. Install Docker and containerlab (inside Linux machine)
sudo apt update && sudo apt install docker.io
curl -sL https://get.containerlab.dev | sudo bash

# 5. Clone project and test
git clone <your-repo-url>
cd train-juniper
sudo containerlab deploy -t test/fixtures/juniper-lab.yml
```

**Option 2: UTM Virtual Machine**
```bash
# Traditional VM approach if OrbStack unavailable
# Create Ubuntu 22.04 VM with 4GB RAM, 2 CPUs
# Install Docker + containerlab inside VM
```

**Option 3: Docker Desktop + Workarounds**
```bash
# Limited approach - containerlab via Docker container
docker run --rm -it --privileged \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/labs \
  ghcr.io/srl-labs/containerlab:latest deploy -t /labs/test/fixtures/juniper-lab.yml
```

### Verification Commands
```bash
# Check if image is ARM64 native (best performance)
docker image inspect vrnetlab/vr-vsrx:23.2R1.13 -f '{{.Architecture}}'

# Expected: arm64 (best) or amd64 (will work with emulation)
```

## Local Development Workflow

### Setup Steps

1. **Install containerlab** (in Linux VM)
```bash
# Get latest release
sudo wget -O /usr/local/bin/containerlab \
  https://github.com/srl-labs/containerlab/releases/latest/download/containerlab_linux_amd64
sudo chmod +x /usr/local/bin/containerlab
```

2. **Create topology file**
```yaml
# test/fixtures/vsrx-lab.yml
name: train-juniper-test
topology:
  nodes:
    vsrx1:
      kind: juniper_vsrx
      image: vrnetlab/vr-vsrx:23.2R1.13
      mgmt-ipv4: 172.20.20.2
  mgmt:
    network: clab-mgmt
    ipv4-subnet: 172.20.20.0/24
```

3. **Daily development cycle**
```bash
# Deploy lab
sudo containerlab deploy -t test/fixtures/vsrx-lab.yml

# Wait for vSRX boot (takes ~5 minutes)
sudo containerlab inspect train-juniper-test

# Test plugin connection
bundle exec ruby test_connection.rb

# SSH directly to device (for debugging)
ssh admin@172.20.20.2  # Password: admin@123

# Cleanup when done
sudo containerlab destroy -t test/fixtures/vsrx-lab.yml
```

## Getting vSRX Images

### Building vrnetlab vSRX Image

The vSRX image must be built locally (licensing restrictions prevent distribution):

```bash
# 1. Clone vrnetlab (use hellt fork for containerlab compatibility)
git clone https://github.com/hellt/vrnetlab.git
cd vrnetlab

# 2. Navigate to vSRX directory
cd vsrx

# 3. Download Juniper vSRX image
# - Get from Juniper website (requires account)
# - Place .qcow2 file in vsrx/ directory

# 4. Build container image
make

# 5. Verify image creation
docker images | grep vrnetlab
```

### Alternative: Mock Container for Development

If vSRX image unavailable, use mock container for basic development:

```yaml
# test/fixtures/mock-lab.yml  
version: '3.8'
services:
  vsrx-mock:
    image: rastasheep/ubuntu-sshd:18.04
    ports:
      - "2222:22"
    environment:
      SSH_ENABLE_PASSWORD_AUTH: "true"
    command: >
      bash -c "
        echo 'admin:admin123' | chpasswd &&
        # Install mock Juniper commands
        echo '#!/bin/bash' > /usr/local/bin/show &&
        echo 'echo \"Hostname: mock-vsrx\"' >> /usr/local/bin/show &&
        chmod +x /usr/local/bin/show &&
        /usr/sbin/sshd -D
      "
```

## CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/test.yml
name: Test train-juniper
on: [push, pull_request]

jobs:
  integration:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install containerlab
        run: |
          sudo wget -O /usr/local/bin/containerlab \
            https://github.com/srl-labs/containerlab/releases/latest/download/containerlab_linux_amd64
          sudo chmod +x /usr/local/bin/containerlab
      
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.1.6
          bundler-cache: true
      
      - name: Deploy vSRX test lab  
        run: |
          sudo containerlab deploy -t test/fixtures/vsrx-lab.yml
          
      - name: Wait for vSRX boot
        run: |
          echo "Waiting for vSRX to become ready..."
          timeout 600 bash -c 'until ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no admin@172.20.20.2 "show version"; do sleep 30; done'
          
      - name: Run integration tests
        run: |
          bundle exec rake test:integration
          
      - name: Cleanup lab
        if: always()
        run: |
          sudo containerlab destroy -t test/fixtures/vsrx-lab.yml
```

## Connection Details

### vSRX Container Credentials
- **SSH Username**: `admin`
- **SSH Password**: `admin@123` 
- **SSH Port**: 22 (mapped to host via containerlab)
- **NETCONF Port**: 830 (if enabled)

### Connection Options for train-juniper
```ruby
# Connection to containerlab vSRX
options = {
  host: '172.20.20.2',  # containerlab assigns this IP
  port: 22,
  user: 'admin',
  password: 'admin@123',
  timeout: 30  # vSRX may be slower than physical devices
}
```

## Troubleshooting

### Common Issues

1. **vSRX won't start**
   - Check Docker has enough resources (2+ CPU, 4GB+ RAM)
   - Verify KVM support: `ls /dev/kvm`
   - Check logs: `docker logs clab-train-juniper-test-vsrx1`

2. **Connection timeouts**
   - vSRX takes 5+ minutes to fully boot
   - Check container health: `sudo containerlab inspect train-juniper-test`
   - Verify SSH connectivity: `ssh -v admin@172.20.20.2`

3. **Image architecture issues (macOS)**
   - Use ARM64 images when possible
   - Enable Rosetta for x86_64 emulation
   - Consider Linux VM for better performance

### Debug Commands

```bash
# Check container status
sudo containerlab inspect train-juniper-test

# View container logs  
docker logs clab-train-juniper-test-vsrx1

# Direct container access
docker exec -it clab-train-juniper-test-vsrx1 cli

# Test network connectivity
ping 172.20.20.2
telnet 172.20.20.2 22
```

## Performance Considerations

### Resource Requirements
- **vSRX Container**: 2 CPU, 4GB RAM minimum
- **Boot Time**: 5-10 minutes for full startup
- **Disk Space**: ~2GB per vSRX image

### Optimization Tips
- Use ARM64 images on Apple Silicon
- Allocate sufficient Docker resources
- Consider persistent volumes for faster restarts
- Use container health checks to verify readiness

## References

### Documentation
- containerlab: https://containerlab.dev/
- vrnetlab: https://github.com/hellt/vrnetlab  
- containerlab macOS: https://containerlab.dev/macos/
- Train architecture: `/docs/plugins.md`

### Key Research Sources
- Implementation Plan: `TRAIN_JUNIPER_IMPLEMENTATION_PLAN.md`
- Research Summary: `TRAIN_JUNIPER_RESEARCH_SUMMARY.md`
- containerlab examples: https://containerlab.dev/lab-examples/

---

*This document consolidates research from the train-juniper implementation project. It should be updated as we discover new patterns or encounter new challenges.*
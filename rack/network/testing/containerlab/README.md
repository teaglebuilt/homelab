# Containerlab Network Testing Environment

This directory contains a containerlab setup for testing Unifi network configurations with Terraform before deploying to production.

## Overview

This testing environment simulates a Unifi network infrastructure using containerlab, allowing you to:
- Test network configurations safely
- Validate firewall rules and VLAN segmentation
- Test terraform changes before production deployment
- Simulate various network topologies

## Directory Structure

```
containerlab/
├── .env.example           # Environment variables template
├── .gitignore            # Git ignore file for sensitive data
├── render-templates.sh   # Script to render configuration templates
├── topology.yaml.tpl     # Containerlab topology template
├── configs/
│   └── frr/
│       └── core-router/
│           ├── frr.conf.tpl    # FRR configuration template
│           └── daemons         # FRR daemon configuration
└── README.md             # This file
```

## Security

All sensitive information (IP addresses, passwords, network configurations) is stored in environment variables and kept out of version control. Only template files (`.tpl`) are committed to git.

## Quick Start

### 1. Setup Environment

```bash
# Copy the environment template
cp .env.example .env

# Edit .env with your configuration
vim .env
```

### 2. Render Templates

```bash
# Run the render script to generate actual configuration files
./render-templates.sh
```

This will create:
- `topology.yaml` - The containerlab topology
- `configs/frr/core-router/frr.conf` - FRR router configuration

### 3. Deploy the Lab

```bash
# Deploy the containerlab topology
sudo containerlab deploy -t topology.yaml

# Check lab status
sudo containerlab inspect -t topology.yaml
```

### 4. Access the Lab

```bash
# Access the core router
docker exec -it clab-unifi-test-lab-core-router vtysh

# Access a test client
docker exec -it clab-unifi-test-lab-vlan10-client bash
```

### 5. Test Network Connectivity

```bash
# From vlan10-client, test connectivity
ping 10.0.0.1  # Gateway
ping 10.0.1.100  # Should be blocked (guest network)

# Test web servers
curl http://10.0.0.50  # Office network server
```

### 6. Cleanup

```bash
# Destroy the lab
sudo containerlab destroy -t topology.yaml --cleanup
```

## Integration with Terraform

### Testing Terraform Changes

1. **Deploy the test environment:**
   ```bash
   ./render-templates.sh
   sudo containerlab deploy -t topology.yaml
   ```

2. **Configure terraform to use test environment:**
   ```bash
   cd ../../terraform
   cp terraform.tfvars.example test.tfvars
   # Edit test.tfvars with containerlab controller details
   ```

3. **Apply terraform configuration to test:**
   ```bash
   terraform workspace new test
   terraform workspace select test
   terraform apply -var-file="test.tfvars"
   ```

4. **Validate changes in containerlab:**
   ```bash
   # Check routing tables
   docker exec -it clab-unifi-test-lab-core-router vtysh -c "show ip route"

   # Test firewall rules
   docker exec -it clab-unifi-test-lab-vlan20-client ping 10.0.0.100
   ```

## Configuration Variables

Key environment variables in `.env`:

| Variable | Description | Default |
|----------|-------------|---------|
| `LAB_NAME` | Containerlab topology name | unifi-test-lab |
| `OFFICE_NETWORK` | Office VLAN network | 10.0.0.0 |
| `GUEST_NETWORK` | Guest VLAN network | 10.0.1.0 |
| `DMZ_NETWORK` | DMZ network | 192.168.100.0 |
| `OSPF_ENABLED` | Enable OSPF routing | yes |
| `BGP_ENABLED` | Enable BGP routing | no |

## Network Topology

The default topology includes:

- **Core Router**: Simulates USG/UDM with FRR
- **Distribution Switches**: 2x switches for redundancy
- **Access Switches**: 2x edge switches
- **Test Clients**:
  - Office VLAN client (VLAN 10)
  - Guest VLAN client (VLAN 20)
  - DMZ client
- **Test Servers**:
  - Office network web server
  - Guest network web server

## Advanced Usage

### Custom FRR Configuration

Add custom FRR configuration in `.env`:

```bash
CUSTOM_CONFIG="router bgp 65001
 neighbor 192.168.1.2 remote-as 65002
 network 10.0.0.0/24"
```

### Enable Additional Routing Protocols

```bash
# In .env
BGP_ENABLED=yes
OSPF6_ENABLED=yes
```

### Modify Network Segments

```bash
# In .env
OFFICE_NETWORK=172.16.0.0
OFFICE_PREFIX=24
OFFICE_NETWORK_GW=172.16.0.1
```

## Troubleshooting

### Common Issues

1. **Template rendering fails:**
   ```bash
   # Check for missing environment variables
   grep -v '^#' .env | xargs -I {} echo {}
   ```

2. **Container startup issues:**
   ```bash
   # Check container logs
   docker logs clab-unifi-test-lab-core-router
   ```

3. **Network connectivity problems:**
   ```bash
   # Check routing table
   docker exec -it clab-unifi-test-lab-core-router ip route show

   # Check interfaces
   docker exec -it clab-unifi-test-lab-core-router ip addr show
   ```

### Debug Mode

Enable debug logging in FRR:

```bash
docker exec -it clab-unifi-test-lab-core-router vtysh
configure terminal
debug ospf events
debug ospf packet all
```

## CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: Test Network Configuration

on:
  pull_request:
    paths:
      - 'rack/network/**'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Install containerlab
        run: |
          sudo apt-get update
          sudo sh -c "echo 'deb [trusted=yes] https://netdevops.fury.site/apt/ /' > /etc/apt/sources.list.d/netdevops.list"
          sudo apt-get update && sudo apt-get install -y containerlab

      - name: Render templates
        run: |
          cd rack/network/testing/containerlab
          cp .env.example .env
          ./render-templates.sh

      - name: Deploy test lab
        run: |
          cd rack/network/testing/containerlab
          sudo containerlab deploy -t topology.yaml

      - name: Run tests
        run: |
          # Add your network tests here
          docker exec clab-unifi-test-lab-vlan10-client ping -c 4 10.0.0.1

      - name: Cleanup
        if: always()
        run: |
          cd rack/network/testing/containerlab
          sudo containerlab destroy -t topology.yaml --cleanup
```

## Contributing

When making changes:
1. Update `.env.example` with new variables
2. Update template files (`.tpl`)
3. Test locally with containerlab
4. Document changes in this README
5. Never commit `.env` or rendered files

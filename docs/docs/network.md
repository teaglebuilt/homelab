# Network

## Provisioning

`rack/network/terraform` provisions all network configurations.

## Testing

`rack/network/testing` sets up infrastructure for testing provisioning on an emulated environment using [containerlab](https://github.com/srl-labs/containerlab)

### What CAN Be Tested

- Firewall rules and policies
- VLAN configurations
- Routing tables
- DHCP configurations
- DNS records
- Port forwarding rules
- Network topology
- VPN configurations
- Traffic shaping policies
- Network segmentation
- Security policies

### What CANNOT Be Tested

- Actual wireless performance
- Client roaming behavior
- RF interference handling
- Physical port configurations
- PoE settings
- Actual device adoption
- Real traffic patterns
- Hardware-specific features

## Troubleshooting

### Controller Won't Start

```bash
# Check container logs
docker-compose -f docker-compose.test.yaml logs unifi-test

# Reset controller
docker-compose -f docker-compose.test.yaml down -v
docker-compose -f docker-compose.test.yaml up -d
```

### Terraform Apply Fails

```bash
# Check controller connectivity
curl -k https://localhost:8443

# Verify credentials
terraform console
> var.unifi_password

# Check provider configuration
terraform providers
```

### State Drift

```bash
# Detect drift
terraform plan -detailed-exitcode

# Refresh state
terraform refresh

# Import missing resources
terraform import unifi_network.main <network-id>
```

## Additional Resources

- [Unifi Terraform Provider Documentation](https://registry.terraform.io/providers/paultyng/unifi/latest/docs)
- [Containerlab Documentation](https://containerlab.dev/)
- [Unifi Network Application API](https://ubntwiki.com/products/software/unifi-controller/api)
- [Network Testing Best Practices](../docs/network-testing.md)

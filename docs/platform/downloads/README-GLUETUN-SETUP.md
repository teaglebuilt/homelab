# Gluetun VPN in Unprivileged LXC: Implementation Guide

## Problem Statement

Gluetun requires:
- `NET_ADMIN` capability to create VPN tunnels
- Access to `/dev/net/tun` character device
- Unprivileged LXC containers don't have these by default
- Terraform API tokens cannot create privileged containers

## Current Approach Issues

Your current `null_resource` approach (lines 275-296 in `lxc.tf`) has critical flaws:

### 1. **Non-Idempotent**
```bash
cat >> /etc/pve/lxc/105.conf  # Appends on EVERY apply
```
Result: Config duplicates indefinitely, eventually corrupting the file.

### 2. **Race Condition**
```
Container created → Provisioners run → null_resource stops/starts container
```
The container restarts *after* Docker installation, so gluetun would fail on first boot.

### 3. **Security Risk**
```bash
lxc.cap.drop:  # Empty value = drops ALL capability restrictions
```
This is equivalent to a privileged container - defeats the entire security model.

### 4. **Fragile**
Direct file manipulation bypasses Terraform state, making drift detection impossible.

## Recommended Solutions (Ranked)

### ✅ Solution 1: One-Time Manual Config (RECOMMENDED)

**Best for**: Production deployments where config rarely changes.

**Pros**:
- Idempotent by design
- No Terraform complexity
- Configuration persists across rebuilds (as long as VM ID doesn't change)
- No race conditions

**Cons**:
- Requires manual SSH access to Proxmox once
- Not fully automated in Terraform

**Implementation**:

1. **One-time setup on Proxmox host**:
```bash
ssh root@<proxmox-ip>

# Add gluetun config to container 105
cat >> /etc/pve/lxc/105.conf <<'EOF'
# Gluetun VPN support
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
lxc.cap.keep: NET_ADMIN
EOF

# Restart container to apply
pct stop 105
pct start 105
```

2. **Remove `null_resource.lxc_privileged_config` from your Terraform**:
```hcl
# DELETE lines 275-296 from lxc.tf
# resource "null_resource" "lxc_privileged_config" { ... }
```

3. **Deploy normally**:
```bash
terraform apply
```

**Why this works**:
- LXC config in `/etc/pve/lxc/105.conf` persists independently of Terraform
- As long as you keep VM ID 105, config survives `terraform destroy/apply`
- Terraform manages everything *except* the capability grants

---

### ✅ Solution 2: Idempotent null_resource with grep check

**Best for**: Fully automated deployments, CI/CD pipelines.

**Pros**:
- Fully automated in Terraform
- Idempotent (won't duplicate lines)
- Can be version controlled

**Cons**:
- Still requires SSH to Proxmox host
- More complex than Solution 1

**Implementation**:

Replace your current `null_resource` (lines 275-296) with:

```hcl
resource "null_resource" "lxc_gluetun_config" {
  # Only re-run if container is recreated
  triggers = {
    container_id = proxmox_virtual_environment_container.portainer.id
  }

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(var.proxmox_ssh_private_key)
    host        = var.proxmox_server_ip
  }

  # Phase 1: Apply config only if not already present
  provisioner "remote-exec" {
    inline = [
      # Check if config already exists
      "if ! grep -q 'lxc.cap.keep.*NET_ADMIN' /etc/pve/lxc/105.conf; then",
      "  pct stop 105 || true",
      "  cat >> /etc/pve/lxc/105.conf <<'EOF'",
      "# Gluetun VPN support - added by Terraform",
      "lxc.cgroup2.devices.allow: c 10:200 rwm",
      "lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file",
      "lxc.cap.keep: NET_ADMIN",
      "EOF",
      "  pct start 105",
      "  # Wait for container to be ready for provisioners",
      "  sleep 10",
      "else",
      "  echo 'Gluetun config already present, skipping'",
      "fi"
    ]
  }
}

# Ensure this runs BEFORE container provisioners
resource "proxmox_virtual_environment_container" "portainer" {
  # ... existing config ...

  # Add explicit dependency
  depends_on = [null_resource.lxc_gluetun_config]

  # ... rest of config ...
}
```

**Critical fix**: The dependency must be reversed:
```
null_resource (config) → container creation → provisioners
```

However, this won't work because Terraform creates the container resource *before* the null_resource can run. This brings us to...

---

### ✅ Solution 3: Two-Stage Terraform Apply (ACTUAL BEST AUTOMATED SOLUTION)

**Best for**: Automated deployments with acceptable two-stage process.

**Implementation**:

Create `/Users/teaglebuilt/github/teaglebuilt/homelab/containers/terraform/lxc-base.tf`:

```hcl
# Stage 1: Create container WITHOUT provisioners
resource "proxmox_virtual_environment_container" "portainer_base" {
  node_name     = "pve"
  start_on_boot = true
  unprivileged  = true
  vm_id         = 105
  started       = false  # Don't start it yet

  # ... all your existing config (cpu, memory, network, etc.) ...
  # BUT remove all provisioner blocks
}
```

Create `/Users/teaglebuilt/github/teaglebuilt/homelab/containers/terraform/lxc-config.tf`:

```hcl
resource "null_resource" "lxc_gluetun_config" {
  depends_on = [proxmox_virtual_environment_container.portainer_base]

  triggers = {
    # Re-run if config file changes
    config_hash = md5(file("${path.module}/lxc-gluetun.conf"))
  }

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(var.proxmox_ssh_private_key)
    host        = var.proxmox_server_ip
  }

  provisioner "remote-exec" {
    inline = [
      # Idempotent: remove old config if exists, add new
      "sed -i '/# Gluetun VPN support/,/^lxc\\.cap\\.keep: NET_ADMIN/d' /etc/pve/lxc/105.conf",
      "cat >> /etc/pve/lxc/105.conf <<'EOF'",
      "# Gluetun VPN support - managed by Terraform",
      "lxc.cgroup2.devices.allow: c 10:200 rwm",
      "lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file",
      "lxc.cap.keep: NET_ADMIN",
      "EOF",
      # Start container with new config
      "pct start 105"
    ]
  }
}
```

Create `/Users/teaglebuilt/github/teaglebuilt/homelab/containers/terraform/lxc-provision.tf`:

```hcl
resource "null_resource" "portainer_provisioning" {
  depends_on = [null_resource.lxc_gluetun_config]

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(var.proxmox_ssh_private_key)
    host        = var.portainer_ip
  }

  # Wait for container to be fully ready
  provisioner "remote-exec" {
    inline = ["sleep 15"]
  }

  # Install Docker
  provisioner "remote-exec" {
    inline = [
      "apt update && apt install -y apt-transport-https ca-certificates curl software-properties-common git direnv",
      "mkdir -p /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | tee /etc/apt/keyrings/docker.asc > /dev/null",
      "echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu focal stable' | tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "apt update && apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin",
      "systemctl enable --now docker",
      "test -c /dev/net/tun || (echo 'ERROR: /dev/net/tun not available' && exit 1)"
    ]
  }

  # Deploy homelab stack
  provisioner "remote-exec" {
    inline = [
      "git clone https://github.com/teaglebuilt/homelab /opt/homelab",
      "docker compose -f /opt/homelab/containers/compose.yaml up -d"
    ]
  }
}
```

---

## Security Analysis

### Your Current Config (INSECURE):
```bash
lxc.cap.drop:  # Drops ALL capability restrictions
```

This makes the container effectively privileged - any process can do anything.

### Recommended Config (SECURE):
```bash
lxc.cap.keep: NET_ADMIN  # Only keep NET_ADMIN, drop everything else
```

This maintains unprivileged security model while granting only VPN management capability.

**Capabilities Comparison**:

| Capability | Current (lxc.cap.drop:) | Recommended (lxc.cap.keep: NET_ADMIN) |
|------------|-------------------------|---------------------------------------|
| CAP_SYS_ADMIN | ✅ Available | ❌ Dropped |
| CAP_SYS_MODULE | ✅ Available | ❌ Dropped |
| CAP_SYS_BOOT | ✅ Available | ❌ Dropped |
| CAP_NET_ADMIN | ✅ Available | ✅ Available (needed) |
| CAP_CHOWN | ✅ Available | ❌ Dropped |
| All other caps | ✅ Available | ❌ Dropped |

---

## Testing & Validation

After deployment, validate the setup:

```bash
# SSH to Proxmox host
ssh root@<proxmox-ip>

# 1. Verify config applied
cat /etc/pve/lxc/105.conf | grep -A3 "Gluetun"

# 2. Check container capabilities
pct exec 105 -- cat /proc/1/status | grep Cap

# 3. SSH to container
ssh root@<portainer-ip>

# 4. Verify /dev/net/tun exists
ls -l /dev/net/tun
# Should show: crw-rw-rw- 1 root root 10, 200 <date> /dev/net/tun

# 5. Test gluetun can create tunnel
docker run --rm \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun \
  -e VPN_SERVICE_PROVIDER=mullvad \
  qmcgaw/gluetun:latest \
  /bin/sh -c "ip tuntap add mode tun dev tun0 && echo 'SUCCESS: TUN device created'"
```

---

## Migration Path

To migrate from your current setup to Solution 1 (recommended):

```bash
# 1. SSH to Proxmox
ssh root@<proxmox-ip>

# 2. Verify current config
cat /etc/pve/lxc/105.conf

# 3. If you see duplicate entries, clean them up:
# Backup first
cp /etc/pve/lxc/105.conf /etc/pve/lxc/105.conf.backup

# Remove all Terraform-added lines
sed -i '/lxc.cgroup2.devices.allow.*10:200/d' /etc/pve/lxc/105.conf
sed -i '/lxc.mount.entry.*tun/d' /etc/pve/lxc/105.conf
sed -i '/lxc.cap.drop:/d' /etc/pve/lxc/105.conf

# 4. Add clean config (one time)
cat >> /etc/pve/lxc/105.conf <<'EOF'
# Gluetun VPN support
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
lxc.cap.keep: NET_ADMIN
EOF

# 5. Restart container
pct stop 105
pct start 105

# 6. Update Terraform - remove lines 275-296 from lxc.tf
# 7. Run terraform apply - should show no changes to container config
```

---

## Conclusion

**For production**: Use Solution 1 (manual one-time config).
- It's simple, reliable, and configuration persists independently of Terraform.
- You only need to do it once per container ID.

**For full automation**: Use Solution 3 (multi-stage Terraform).
- More complex but fully automated.
- Idempotent and version-controlled.

**Avoid**: Your current approach - it's non-idempotent, insecure, and has race conditions.

The key insight: LXC container configuration is infrastructure, but not all infrastructure needs to be managed by Terraform. Sometimes a one-time manual step is the pragmatic choice in a homelab context.

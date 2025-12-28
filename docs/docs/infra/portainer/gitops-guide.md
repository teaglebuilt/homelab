# Portainer GitOps Deployment Guide

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Approach Comparison](#approach-comparison)
4. [GitHub Actions Setup (Recommended)](#github-actions-setup)
5. [Alternative: Self-Hosted GitOps](#alternative-self-hosted-gitops)
6. [Security Best Practices](#security-best-practices)
7. [Operational Procedures](#operational-procedures)
8. [Troubleshooting](#troubleshooting)

---

## Overview

This guide implements GitOps for Docker Compose deployments on a Portainer LXC container running on Proxmox. The solution provides:

- **Automated deployments** triggered by Git commits
- **Security scanning** for vulnerabilities and secrets
- **Rollback mechanisms** for failed deployments
- **Health checks** to validate deployments
- **Audit logging** for compliance

### Current Infrastructure

```
┌─────────────────────────────────────────────────────────┐
│ Proxmox VE                                              │
│  ┌───────────────────────────────────────────────────┐ │
│  │ LXC Container (VM ID 105)                         │ │
│  │ ┌───────────────────────────────────────────────┐ │ │
│  │ │ Docker Engine                                 │ │ │
│  │ │  ├─ Portainer CE (9443, 9000, 8000)          │ │ │
│  │ │  └─ Homepage Dashboard (3000)                 │ │ │
│  │ └───────────────────────────────────────────────┘ │ │
│  │ IP: 192.168.1.105 (from Terraform vars)          │ │
│  │ Storage: /mnt/local (100GB bind mount)           │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

---

## Architecture

### GitOps Workflow

```
┌──────────────┐      ┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│              │      │              │      │              │      │              │
│   Git Push   │─────▶│   Validate   │─────▶│    Backup    │─────▶│    Deploy    │
│              │      │              │      │              │      │              │
└──────────────┘      └──────────────┘      └──────────────┘      └──────────────┘
                            │                                            │
                            │                                            │
                            ▼                                            ▼
                      ┌──────────────┐                          ┌──────────────┐
                      │  Security    │                          │    Health    │
                      │   Scanning   │                          │    Checks    │
                      └──────────────┘                          └──────────────┘
                                                                        │
                                                                        │
                                                                        ▼
                                                                 ┌──────────────┐
                                                                 │   Notify     │
                                                                 │ (Success/Fail)│
                                                                 └──────────────┘
```

### Deployment Phases

1. **Validation Phase**
   - Syntax validation (`docker compose config`)
   - Version pinning check (no `:latest` tags)
   - Secret scanning (TruffleHog)
   - Container image vulnerability scanning (Trivy)

2. **Backup Phase**
   - Stop Portainer container gracefully
   - Backup Portainer data volume to `/mnt/local/backups`
   - Restart container
   - Verify backup integrity
   - Cleanup old backups (7-day retention)

3. **Deployment Phase**
   - Pre-flight checks (disk space, Docker daemon)
   - Git repository sync
   - Pull container images
   - Rolling update deployment
   - Post-deployment health checks

4. **Notification Phase**
   - Success/failure notifications
   - Integration with Discord/Slack/PagerDuty

---

## Approach Comparison

### 1. GitHub Actions (Recommended) ⭐

**Pros:**
- ✅ No additional infrastructure to maintain
- ✅ Free for public repos, generous free tier for private
- ✅ Strong secrets management (GitHub Secrets)
- ✅ Native integration with GitHub
- ✅ Extensive marketplace of reusable actions
- ✅ Built-in OIDC for cloud provider authentication
- ✅ Audit logs included

**Cons:**
- ❌ Requires internet connectivity
- ❌ Limited to 6 hours per workflow run
- ❌ GitHub-hosted runners have public IPs (use self-hosted for security)

**Best For:** Most use cases, especially if already using GitHub

---

### 2. Gitea Actions (Self-Hosted)

**Pros:**
- ✅ Fully self-hosted and private
- ✅ GitHub Actions compatible syntax
- ✅ No cloud dependencies
- ✅ Free and open source
- ✅ Runs on minimal resources

**Cons:**
- ❌ Additional infrastructure to maintain
- ❌ Smaller ecosystem than GitHub Actions
- ❌ Manual updates required
- ❌ Need to manage runner infrastructure

**Best For:** Privacy-critical environments, air-gapped networks

**Setup:**
```yaml
# Gitea Actions uses .gitea/workflows/ instead of .github/workflows/
# Syntax is 95% compatible with GitHub Actions
```

---

### 3. Woodpecker CI (Lightweight, Container-Native)

**Pros:**
- ✅ Extremely lightweight (single Go binary)
- ✅ Container-native (everything runs in Docker)
- ✅ Simple YAML syntax
- ✅ Built-in secrets management
- ✅ Native Docker Compose support
- ✅ Multi-platform (GitHub, Gitea, GitLab, Bitbucket)

**Cons:**
- ❌ Smaller community than alternatives
- ❌ Less extensive plugin ecosystem
- ❌ Manual infrastructure setup

**Best For:** Kubernetes/Docker-heavy environments, minimalist setups

**Example Pipeline:**
```yaml
# .woodpecker.yml
pipeline:
  validate:
    image: docker/compose:1.29.2
    commands:
      - docker compose -f containers/compose.yaml config

  deploy:
    image: appleboy/drone-ssh:1.7.4
    settings:
      host: 192.168.1.105
      username: root
      key: $${SSH_KEY}
      script:
        - cd /root/homelab
        - git pull origin main
        - docker compose -f containers/compose.yaml up -d
```

---

### 4. Drone CI (Enterprise-Grade)

**Pros:**
- ✅ Enterprise features (RBAC, audit logs)
- ✅ Container-native
- ✅ Extensive plugin ecosystem
- ✅ Cloud and self-hosted options

**Cons:**
- ❌ Complex setup for small environments
- ❌ Cloud version requires subscription
- ❌ Resource-intensive

**Best For:** Large organizations, enterprise compliance requirements

---

### 5. ArgoCD (Kubernetes-Native GitOps)

**Note:** Not directly applicable since you're using Docker Compose, but worth considering if you migrate to Kubernetes.

**Pros:**
- ✅ Kubernetes-native GitOps
- ✅ Declarative configuration
- ✅ Automatic drift detection
- ✅ Web UI for visualization

**Cons:**
- ❌ Requires Kubernetes
- ❌ Overkill for Docker Compose

---

## GitHub Actions Setup (Recommended)

### Prerequisites

1. **GitHub Repository**: Your homelab repo (`teaglebuilt/homelab`)
2. **SSH Access**: Existing SSH key from Terraform setup
3. **Portainer LXC**: IP address accessible from GitHub runners

### Step 1: Configure GitHub Secrets

Navigate to **Settings > Secrets and variables > Actions** and add:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `PORTAINER_IP` | `192.168.1.105` | LXC container IP address |
| `PORTAINER_SSH_KEY` | `<private-key-content>` | SSH private key for root access |
| `DISCORD_WEBHOOK_URL` | `https://discord.com/api/webhooks/...` | (Optional) For notifications |

**Security Note:** The SSH key should be the same one used in Terraform (`var.proxmox_ssh_private_key`).

### Step 2: Update Compose File with Pinned Versions

Replace `containers/compose.yaml` with `containers/compose.production.yaml`:

```bash
# Local testing first
docker compose -f containers/compose.production.yaml config

# Commit and push
git add containers/compose.production.yaml
git commit -m "feat: add production compose with pinned versions"
git push origin main
```

### Step 3: Configure GitHub Environments (Optional but Recommended)

1. Go to **Settings > Environments**
2. Create `production` environment
3. Add protection rules:
   - **Required reviewers**: Add yourself or team
   - **Wait timer**: 5 minutes (gives time to cancel)
4. Add environment-specific secrets if needed

### Step 4: Enable Workflow Permissions

1. Go to **Settings > Actions > General**
2. Under **Workflow permissions**, select:
   - ✅ Read and write permissions
   - ✅ Allow GitHub Actions to create and approve pull requests

### Step 5: Test Deployment

```bash
# Manual trigger via GitHub UI
# 1. Go to Actions tab
# 2. Select "Deploy Portainer Stack"
# 3. Click "Run workflow"
# 4. Select environment: production
# 5. Click "Run workflow"

# Or trigger via commit
git commit --allow-empty -m "chore: trigger deployment"
git push origin main
```

### Step 6: Monitor Deployment

1. Go to **Actions** tab in GitHub
2. Click on running workflow
3. Monitor each job:
   - ✅ Validate
   - ✅ Backup
   - ✅ Deploy
   - ✅ Notify

---

## Alternative: Self-Hosted GitOps

### Option A: Gitea Actions

#### Installation on LXC Container

```bash
# SSH into Portainer LXC
ssh root@192.168.1.105

# Install Gitea (lightweight self-hosted Git server)
wget -O gitea https://dl.gitea.com/gitea/1.22.3/gitea-1.22.3-linux-amd64
chmod +x gitea
sudo mv gitea /usr/local/bin/gitea

# Create systemd service
sudo useradd -r -m -d /var/lib/gitea gitea

sudo tee /etc/systemd/system/gitea.service > /dev/null <<'EOF'
[Unit]
Description=Gitea
After=network.target

[Service]
Type=simple
User=gitea
WorkingDirectory=/var/lib/gitea
ExecStart=/usr/local/bin/gitea web --config /etc/gitea/app.ini
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable gitea
sudo systemctl start gitea
```

#### Configure Gitea Actions Runner

```bash
# Download act_runner (Gitea Actions runner)
wget -O act_runner https://dl.gitea.com/act_runner/0.2.10/act_runner-0.2.10-linux-amd64
chmod +x act_runner
sudo mv act_runner /usr/local/bin/act_runner

# Register runner
act_runner register --instance http://localhost:3000 --token <GITEA_RUNNER_TOKEN>

# Create systemd service
sudo tee /etc/systemd/system/act_runner.service > /dev/null <<'EOF'
[Unit]
Description=Gitea Actions Runner
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/act_runner daemon
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable act_runner
sudo systemctl start act_runner
```

---

### Option B: Woodpecker CI

#### Installation via Docker Compose

```yaml
# woodpecker/compose.yaml
version: '3.8'

services:
  woodpecker-server:
    image: woodpeckerci/woodpecker-server:v3.0.0
    ports:
      - "8080:8080"
    volumes:
      - woodpecker-data:/var/lib/woodpecker
    environment:
      - WOODPECKER_OPEN=true
      - WOODPECKER_HOST=http://192.168.1.105:8080
      - WOODPECKER_GITHUB=true
      - WOODPECKER_GITHUB_CLIENT=${GITHUB_CLIENT_ID}
      - WOODPECKER_GITHUB_SECRET=${GITHUB_CLIENT_SECRET}
      - WOODPECKER_ADMIN=teaglebuilt

  woodpecker-agent:
    image: woodpeckerci/woodpecker-agent:v3.0.0
    command: agent
    depends_on:
      - woodpecker-server
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WOODPECKER_SERVER=woodpecker-server:9000
      - WOODPECKER_AGENT_SECRET=${WOODPECKER_AGENT_SECRET}

volumes:
  woodpecker-data:
```

#### Woodpecker Pipeline

```yaml
# .woodpecker.yml
pipeline:
  validate:
    image: docker/compose:2.31.0
    commands:
      - docker compose -f containers/compose.yaml config --quiet

  deploy:
    image: appleboy/drone-ssh:1.7.4
    secrets: [ssh_key]
    settings:
      host: 192.168.1.105
      username: root
      key_path: /run/secrets/ssh_key
      script:
        - cd /root/homelab
        - git pull origin main
        - docker compose -f containers/compose.yaml up -d --remove-orphans

  notify:
    image: plugins/webhook:1.14.0
    settings:
      urls: ${DISCORD_WEBHOOK_URL}
      content_type: application/json
      template: |
        {
          "content": "Deployment {{ build.status }} for commit {{ commit.sha }}"
        }
```

---

## Security Best Practices

### 1. SSH Key Management

#### Generate Dedicated Deployment Key

```bash
# On your local machine
ssh-keygen -t ed25519 -C "github-actions-deployment" -f ~/.ssh/portainer-deploy
```

#### Add Public Key to LXC Container

```bash
# SSH into LXC
ssh root@192.168.1.105

# Add public key
mkdir -p ~/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... github-actions-deployment" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

#### Store Private Key in GitHub Secrets

```bash
# Copy private key to clipboard
cat ~/.ssh/portainer-deploy | pbcopy  # macOS
# or
cat ~/.ssh/portainer-deploy | xclip -selection clipboard  # Linux
```

Then paste into GitHub Secret `PORTAINER_SSH_KEY`.

---

### 2. Secrets Injection into Compose Files

#### Using Environment Variables

```yaml
# compose.yaml
services:
  app:
    environment:
      - DATABASE_PASSWORD=${DB_PASSWORD}  # Injected at runtime
```

#### Using Docker Secrets (Swarm Mode)

```yaml
# compose.yaml
version: '3.8'

services:
  app:
    secrets:
      - db_password
    environment:
      - DATABASE_PASSWORD_FILE=/run/secrets/db_password

secrets:
  db_password:
    external: true
```

#### Using SOPS (Secrets OPerationS)

```bash
# Install SOPS
brew install sops  # macOS
# or
sudo apt install sops  # Ubuntu

# Install age for encryption
brew install age

# Generate age key
age-keygen -o ~/.config/sops/age/keys.txt

# Encrypt secrets file
sops --encrypt --age $(cat ~/.config/sops/age/keys.txt | grep "public key" | cut -d: -f2) \
  containers/.env.secrets > containers/.env.secrets.enc

# Decrypt in workflow
sops --decrypt containers/.env.secrets.enc > containers/.env.secrets
```

#### GitHub Actions Example with Secrets

```yaml
- name: Deploy with Secrets
  env:
    DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
    API_KEY: ${{ secrets.API_KEY }}
  run: |
    ssh ${{ env.SSH_USER }}@${{ env.PORTAINER_HOST }} << 'EOF'
      cd /root/homelab
      echo "DB_PASSWORD=${{ env.DB_PASSWORD }}" > .env
      echo "API_KEY=${{ env.API_KEY }}" >> .env
      docker compose -f containers/compose.yaml up -d
    EOF
```

---

### 3. Network Security

#### Restrict SSH Access (IP Whitelist)

```bash
# On LXC container
sudo ufw allow from 140.82.112.0/20 to any port 22  # GitHub Actions IP range
sudo ufw enable
```

#### Use Tailscale/WireGuard for Private Network

```bash
# Install Tailscale on LXC
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# Get Tailscale IP
tailscale ip -4  # e.g., 100.101.102.103

# Update GitHub Secret PORTAINER_IP to Tailscale IP
```

#### SSH Hardening

```bash
# /etc/ssh/sshd_config
PermitRootLogin prohibit-password
PubkeyAuthentication yes
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2

# Restart SSH
sudo systemctl restart sshd
```

---

### 4. Audit Logging

#### Enable Docker Audit Logging

```json
// /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3",
    "labels": "production"
  },
  "audit": {
    "level": "info"
  }
}
```

#### GitHub Actions Audit Logs

- Available at **Settings > Security > Logs**
- Includes: workflow runs, secret access, approval events

#### LXC Container Audit Logging

```bash
# Install auditd
sudo apt install auditd

# Monitor Docker socket access
sudo auditctl -w /var/run/docker.sock -p rwxa -k docker_socket

# Monitor compose file changes
sudo auditctl -w /root/homelab/containers/compose.yaml -p wa -k compose_changes

# View audit logs
sudo ausearch -k docker_socket
```

---

## Operational Procedures

### Manual Deployment Trigger

```bash
# Via GitHub CLI
gh workflow run deploy-portainer.yaml -f environment=production

# Via curl
curl -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/repos/teaglebuilt/homelab/actions/workflows/deploy-portainer.yaml/dispatches \
  -d '{"ref":"main","inputs":{"environment":"production"}}'
```

### Emergency Rollback

#### Via GitHub Actions

```bash
# Trigger rollback workflow
gh workflow run deploy-portainer.yaml \
  -f environment=production \
  -f rollback=true
```

#### Manual Rollback

```bash
# SSH into container
ssh root@192.168.1.105

cd /root/homelab

# View commit history
git log --oneline -10

# Rollback to specific commit
git reset --hard <commit-hash>

# Redeploy
docker compose -f containers/compose.yaml up -d --remove-orphans
```

### Backup Restoration

```bash
# SSH into container
ssh root@192.168.1.105

# List backups
ls -lh /mnt/local/backups/portainer-backup-*.tar.gz

# Stop Portainer
docker compose -f /root/homelab/containers/compose.yaml stop portainer

# Restore backup
BACKUP_FILE="/mnt/local/backups/portainer-backup-20250126-120000.tar.gz"

docker run --rm \
  -v portainer_data:/data \
  -v /mnt/local/backups:/backup:ro \
  alpine:3.21.0 \
  sh -c "cd /data && tar xzf /backup/$(basename $BACKUP_FILE)"

# Start Portainer
docker compose -f /root/homelab/containers/compose.yaml start portainer
```

---

## Troubleshooting

### Deployment Failures

#### Check Workflow Logs

```bash
# Via GitHub CLI
gh run list --workflow=deploy-portainer.yaml --limit 5
gh run view <run-id> --log
```

#### Check Container Logs on LXC

```bash
ssh root@192.168.1.105
cd /root/homelab
docker compose -f containers/compose.yaml logs --tail=100 portainer
```

#### Common Issues

**Issue**: SSH connection timeout

```bash
# Verify SSH connectivity
ssh -v root@192.168.1.105

# Check SSH service
systemctl status sshd

# Check firewall
sudo ufw status
```

**Issue**: Docker daemon not running

```bash
# Check Docker status
systemctl status docker

# Restart Docker
systemctl restart docker
```

**Issue**: Disk space full

```bash
# Check disk usage
df -h /mnt/local

# Clean up Docker resources
docker system prune -af --volumes

# Clean up old backups
find /mnt/local/backups -name "portainer-backup-*.tar.gz" -mtime +7 -delete
```

---

## Cost Analysis

### GitHub Actions (Free Tier)

- **Free minutes/month**: 2,000 minutes (public repos unlimited)
- **Storage**: 500 MB for artifacts
- **Cost per minute (private repos)**: $0.008 for Ubuntu runners

**Estimated monthly usage:**
- 10 deployments/month × 5 minutes = 50 minutes
- **Monthly cost**: $0 (within free tier)

### Self-Hosted Gitea Actions

- **LXC Resources**: +0.5 CPU, +512MB RAM
- **Storage**: ~500MB for Gitea + runner
- **Network**: Minimal (LAN only)
- **Monthly cost**: $0 (uses existing infrastructure)

### Woodpecker CI

- **LXC Resources**: +1 CPU, +1GB RAM
- **Storage**: ~1GB for server + agents
- **Monthly cost**: $0 (self-hosted)

---

## Next Steps

1. **Immediate Actions**
   - [ ] Add GitHub Secrets (PORTAINER_IP, PORTAINER_SSH_KEY)
   - [ ] Update compose.yaml with pinned versions
   - [ ] Test deployment workflow manually
   - [ ] Configure Discord/Slack notifications

2. **Security Hardening**
   - [ ] Implement SSH key rotation policy
   - [ ] Enable UFW firewall on LXC
   - [ ] Set up audit logging
   - [ ] Review and restrict container capabilities

3. **Advanced Features**
   - [ ] Implement blue-green deployments
   - [ ] Add performance testing stage
   - [ ] Set up centralized logging (Loki)
   - [ ] Integrate with monitoring (Prometheus/Grafana)

---

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Compose Best Practices](https://docs.docker.com/compose/production/)
- [Trivy Container Scanner](https://github.com/aquasecurity/trivy)
- [SOPS Secrets Management](https://github.com/mozilla/sops)
- [Gitea Actions](https://docs.gitea.io/en-us/actions/)
- [Woodpecker CI](https://woodpecker-ci.org/)

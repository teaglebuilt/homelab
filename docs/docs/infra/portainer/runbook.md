# Portainer Operations Runbook

## Quick Reference

**LXC Container Details:**
- VM ID: 105
- Default IP: 192.168.1.105 (from Terraform)
- OS: Ubuntu 20.04
- Resources: 2 cores, 3GB RAM, 10GB disk + 100GB mount
- Storage: `/mnt/local` (100GB bind mount for Docker data)

**Service Endpoints:**
- Portainer HTTPS: https://192.168.1.105:9443
- Portainer HTTP: http://192.168.1.105:9000
- Homepage: http://192.168.1.105:3000

**Important Paths:**
- Repository: `/root/homelab`
- Compose file: `/root/homelab/containers/compose.yaml`
- Backups: `/mnt/local/backups`
- Docker data: `/mnt/local/docker`
- Logs: `/var/log/portainer-deploy.log`

---

## Standard Operating Procedures

### 1. Manual Deployment

#### Via Deployment Script (Recommended)

```bash
# SSH into container
ssh root@192.168.1.105

# Navigate to repository
cd /root/homelab

# Pull latest changes
git pull origin main

# Run deployment script
bash containers/scripts/deploy.sh

# Check status
docker compose -f containers/compose.yaml ps
```

#### Via GitHub Actions

```bash
# Method 1: GitHub CLI
gh workflow run deploy-portainer.yaml -f environment=production

# Method 2: GitHub Web UI
# 1. Navigate to Actions tab
# 2. Select "Deploy Portainer Stack"
# 3. Click "Run workflow"
# 4. Select branch and environment
# 5. Click "Run workflow"

# Method 3: API call
curl -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/repos/teaglebuilt/homelab/actions/workflows/deploy-portainer.yaml/dispatches \
  -d '{"ref":"main","inputs":{"environment":"production"}}'
```

---

### 2. Rollback Procedures

#### Automatic Rollback (via GitHub Actions)

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

# Option A: Use deployment script
bash containers/scripts/deploy.sh --rollback

# Option B: Manual Git rollback
# View recent commits
git log --oneline -10

# Reset to previous commit
git reset --hard <commit-hash>

# Redeploy
docker compose -f containers/compose.yaml up -d --remove-orphans

# Verify health
curl -k https://localhost:9443/api/system/status
```

#### Backup Restoration

```bash
ssh root@192.168.1.105

# List available backups
ls -lh /mnt/local/backups/portainer-backup-*.tar.gz

# Choose backup to restore
BACKUP_FILE="/mnt/local/backups/portainer-backup-20250126-120000.tar.gz"

# Stop Portainer
docker compose -f /root/homelab/containers/compose.yaml stop portainer

# Restore backup
docker run --rm \
  -v portainer_data:/data \
  -v /mnt/local/backups:/backup:ro \
  alpine:3.21.0 \
  sh -c "rm -rf /data/* && tar xzf /backup/$(basename $BACKUP_FILE) -C /data"

# Start Portainer
docker compose -f /root/homelab/containers/compose.yaml start portainer

# Verify
docker logs portainer
curl -k https://localhost:9443/api/system/status
```

---

### 3. Health Checks

#### Container Health

```bash
# SSH into container
ssh root@192.168.1.105

# Check container status
docker compose -f /root/homelab/containers/compose.yaml ps

# Check container logs
docker compose -f /root/homelab/containers/compose.yaml logs portainer --tail=100
docker compose -f /root/homelab/containers/compose.yaml logs homepage --tail=100

# Check resource usage
docker stats --no-stream

# Check container health
docker inspect portainer --format='{{.State.Health.Status}}'
```

#### Service Health

```bash
# Portainer API health
curl -k https://192.168.1.105:9443/api/system/status

# Expected response:
# {"Version":"2.21.4"}

# Homepage health
curl http://192.168.1.105:3000

# Expected: HTTP 200 with HTML content
```

#### System Health

```bash
ssh root@192.168.1.105

# Check disk space
df -h /mnt/local

# Check memory usage
free -h

# Check CPU usage
top -bn1 | head -20

# Check Docker daemon
systemctl status docker

# Check recent Docker events
docker events --since 1h --until now
```

---

### 4. Backup Management

#### Manual Backup

```bash
ssh root@192.168.1.105

# Create backup directory
mkdir -p /mnt/local/backups

# Create backup
BACKUP_NAME="portainer-backup-$(date +%Y%m%d-%H%M%S).tar.gz"

docker compose -f /root/homelab/containers/compose.yaml stop portainer

docker run --rm \
  -v portainer_data:/data:ro \
  -v /mnt/local/backups:/backup \
  alpine:3.21.0 \
  tar czf "/backup/$BACKUP_NAME" -C /data .

docker compose -f /root/homelab/containers/compose.yaml start portainer

# Verify backup
ls -lh /mnt/local/backups/$BACKUP_NAME
```

#### Scheduled Backups (Cron)

```bash
# Create backup script
sudo tee /usr/local/bin/backup-portainer.sh > /dev/null <<'EOF'
#!/bin/bash
set -euo pipefail

BACKUP_DIR="/mnt/local/backups"
BACKUP_NAME="portainer-backup-$(date +%Y%m%d-%H%M%S).tar.gz"

cd /root/homelab
docker compose -f containers/compose.yaml stop portainer

docker run --rm \
  -v portainer_data:/data:ro \
  -v "$BACKUP_DIR":/backup \
  alpine:3.21.0 \
  tar czf "/backup/$BACKUP_NAME" -C /data .

docker compose -f containers/compose.yaml start portainer

# Cleanup old backups (keep 30 days)
find "$BACKUP_DIR" -name "portainer-backup-*.tar.gz" -mtime +30 -delete

echo "Backup completed: $BACKUP_NAME"
EOF

sudo chmod +x /usr/local/bin/backup-portainer.sh

# Add to crontab (daily at 2 AM)
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/backup-portainer.sh >> /var/log/portainer-backup.log 2>&1") | crontab -

# Verify cron job
crontab -l
```

#### Off-site Backup (to S3)

```bash
# Install AWS CLI
sudo apt install awscli

# Configure AWS credentials
aws configure

# Modify backup script to upload to S3
sudo tee -a /usr/local/bin/backup-portainer.sh > /dev/null <<'EOF'

# Upload to S3
aws s3 cp "$BACKUP_DIR/$BACKUP_NAME" s3://your-bucket/portainer-backups/

echo "Backup uploaded to S3"
EOF
```

---

### 5. Log Management

#### View Deployment Logs

```bash
ssh root@192.168.1.105

# View deployment script logs
tail -f /var/log/portainer-deploy.log

# View last 100 lines
tail -100 /var/log/portainer-deploy.log

# Search for errors
grep ERROR /var/log/portainer-deploy.log
```

#### View Container Logs

```bash
# Real-time logs
docker compose -f /root/homelab/containers/compose.yaml logs -f

# Last 100 lines
docker compose -f /root/homelab/containers/compose.yaml logs --tail=100

# Specific service
docker compose -f /root/homelab/containers/compose.yaml logs portainer --tail=50

# Filter by time
docker compose -f /root/homelab/containers/compose.yaml logs --since 1h portainer
```

#### Export Logs for Analysis

```bash
# Export container logs
docker compose -f /root/homelab/containers/compose.yaml logs --no-color > /tmp/container-logs.txt

# Transfer to local machine
scp root@192.168.1.105:/tmp/container-logs.txt ./

# Or view with less
docker compose -f /root/homelab/containers/compose.yaml logs --no-color | less
```

---

### 6. Container Updates

#### Update Specific Service

```bash
ssh root@192.168.1.105
cd /root/homelab

# Update compose file with new image version
# Edit: containers/compose.yaml
# Change: portainer/portainer-ce:2.21.4-alpine
# To:     portainer/portainer-ce:2.21.5-alpine

# Pull new image
docker compose -f containers/compose.yaml pull portainer

# Recreate container
docker compose -f containers/compose.yaml up -d portainer

# Verify
docker compose -f containers/compose.yaml ps
docker logs portainer --tail=50
```

#### Update All Services

```bash
cd /root/homelab

# Pull all new images
docker compose -f containers/compose.yaml pull

# Recreate all containers
docker compose -f containers/compose.yaml up -d

# Verify
docker compose -f containers/compose.yaml ps
```

---

### 7. Troubleshooting

#### Container Won't Start

```bash
# Check container status
docker compose -f /root/homelab/containers/compose.yaml ps -a

# Check logs for errors
docker compose -f /root/homelab/containers/compose.yaml logs portainer

# Inspect container
docker inspect portainer

# Common issues:
# 1. Port already in use
sudo netstat -tulpn | grep -E ':(9443|9000|8000|3000)'

# 2. Volume permission issues
docker run --rm -v portainer_data:/data alpine ls -la /data

# 3. Docker socket permission
ls -la /var/run/docker.sock

# 4. Memory/CPU limits
docker stats --no-stream
```

#### Network Issues

```bash
# Check Docker networks
docker network ls
docker network inspect <network-name>

# Check container network connectivity
docker exec portainer ping -c 3 8.8.8.8
docker exec portainer ping -c 3 google.com

# Check DNS
docker exec portainer cat /etc/resolv.conf

# Check firewall
sudo ufw status
sudo iptables -L -n
```

#### Disk Space Issues

```bash
# Check disk usage
df -h /mnt/local

# Clean up Docker resources
docker system df

# Remove unused images
docker image prune -a

# Remove unused volumes
docker volume prune

# Remove unused networks
docker network prune

# Remove all unused resources
docker system prune -af --volumes
```

#### Performance Issues

```bash
# Check resource usage
docker stats

# Check system load
htop

# Check I/O wait
iostat -x 5

# Check logs for errors
journalctl -u docker --since "1 hour ago"

# Check Docker daemon logs
sudo journalctl -u docker.service --no-pager | tail -100
```

---

### 8. Security Operations

#### Review Access Logs

```bash
# SSH access logs
sudo grep sshd /var/log/auth.log | tail -50

# Docker API access (if exposed)
sudo journalctl -u docker --since today | grep -i api

# Failed login attempts
sudo grep "Failed password" /var/log/auth.log
```

#### Update SSH Keys

```bash
# Add new key
echo "ssh-ed25519 AAAAC3... new-key" >> ~/.ssh/authorized_keys

# Remove old key
sed -i '/old-key-comment/d' ~/.ssh/authorized_keys

# Verify
cat ~/.ssh/authorized_keys
```

#### Rotate Secrets

```bash
# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)

# Update in Portainer UI or via API
curl -k -X POST https://localhost:9443/api/users/admin/password \
  -H "Authorization: Bearer $PORTAINER_TOKEN" \
  -d "{\"password\":\"$NEW_PASSWORD\"}"

# Update in GitHub Secrets
gh secret set PORTAINER_ADMIN_PASSWORD -b "$NEW_PASSWORD"
```

#### Security Audit

```bash
# Check for CVEs in images
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:0.56.2 image portainer/portainer-ce:2.21.4-alpine

# Check container security
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:0.56.2 container portainer

# Review Docker daemon config
cat /etc/docker/daemon.json

# Check file permissions
ls -la /var/run/docker.sock
ls -la /mnt/local/docker
```

---

### 9. Disaster Recovery

#### Complete System Failure

```bash
# 1. Provision new LXC container via Terraform
cd /path/to/homelab
task containers:provision

# 2. SSH into new container
ssh root@192.168.1.105

# 3. Clone repository
git clone https://github.com/teaglebuilt/homelab
cd homelab

# 4. Restore latest backup
LATEST_BACKUP=$(ls -t /mnt/local/backups/portainer-backup-*.tar.gz | head -1)

docker compose -f containers/compose.yaml up -d --no-start

docker run --rm \
  -v portainer_data:/data \
  -v /mnt/local/backups:/backup:ro \
  alpine:3.21.0 \
  tar xzf "/backup/$(basename $LATEST_BACKUP)" -C /data

docker compose -f containers/compose.yaml start

# 5. Verify
docker compose -f containers/compose.yaml ps
curl -k https://localhost:9443/api/system/status
```

#### Data Corruption

```bash
# 1. Stop affected container
docker compose -f /root/homelab/containers/compose.yaml stop portainer

# 2. Restore from known good backup
GOOD_BACKUP="/mnt/local/backups/portainer-backup-20250125-020000.tar.gz"

docker run --rm \
  -v portainer_data:/data \
  -v /mnt/local/backups:/backup:ro \
  alpine:3.21.0 \
  sh -c "rm -rf /data/* && tar xzf /backup/$(basename $GOOD_BACKUP) -C /data"

# 3. Restart
docker compose -f /root/homelab/containers/compose.yaml start portainer

# 4. Verify
docker logs portainer
```

---

### 10. Monitoring and Alerting

#### Set Up Simple Monitoring

```bash
# Create monitoring script
sudo tee /usr/local/bin/monitor-portainer.sh > /dev/null <<'EOF'
#!/bin/bash

WEBHOOK_URL="https://discord.com/api/webhooks/YOUR_WEBHOOK"

# Check Portainer health
if ! curl -k -f -s https://localhost:9443/api/system/status > /dev/null; then
    curl -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d '{"content":"🚨 Portainer is DOWN!"}'
fi

# Check disk space
DISK_USAGE=$(df /mnt/local | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    curl -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{\"content\":\"⚠️ Disk usage is ${DISK_USAGE}%!\"}"
fi
EOF

sudo chmod +x /usr/local/bin/monitor-portainer.sh

# Add to crontab (every 5 minutes)
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/monitor-portainer.sh") | crontab -
```

#### Check Metrics

```bash
# Container uptime
docker inspect portainer --format='{{.State.StartedAt}}'

# Container restart count
docker inspect portainer --format='{{.RestartCount}}'

# Image age
docker inspect portainer/portainer-ce:2.21.4-alpine --format='{{.Created}}'

# Volume size
docker system df -v | grep portainer_data
```

---

## Emergency Contacts

- **On-Call Engineer**: [Your contact]
- **GitHub Repository**: https://github.com/teaglebuilt/homelab
- **Proxmox Admin**: [Proxmox admin contact]

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-01-26 | Initial runbook creation | DevOps Team |

---

## Appendix: Useful Commands

```bash
# Quick health check
ssh root@192.168.1.105 'docker ps && curl -k -s https://localhost:9443/api/system/status'

# Quick restart
ssh root@192.168.1.105 'cd /root/homelab && docker compose -f containers/compose.yaml restart'

# View logs from local machine
ssh root@192.168.1.105 'docker logs portainer --tail=100'

# Execute command in container
ssh root@192.168.1.105 'docker exec portainer /bin/sh -c "df -h"'

# Copy file from container
ssh root@192.168.1.105 'docker cp portainer:/data/portainer.db /tmp/'
scp root@192.168.1.105:/tmp/portainer.db ./
```

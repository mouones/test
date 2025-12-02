# 🚀 Complete Deployment Guide - Optimized Storage & All Frameworks

## Pre-Deployment: Storage Optimization

### Step 1: Upload Optimization Script
```powershell
# From Windows
scp optimize-storage.sh root@192.168.171.140:/root/
scp app-final-optimized.py root@192.168.171.140:/root/
```

### Step 2: Run Storage Cleanup
```bash
# SSH to Proxmox
ssh root@192.168.171.140

# Make script executable
chmod +x /root/optimize-storage.sh

# Run optimization
./optimize-storage.sh
```

**This will:**
- ✅ Clean /tmp directory
- ✅ Remove old logs
- ✅ Clean APT cache
- ✅ Remove orphaned VM/CT disks
- ✅ Detect and add new 120GB disk
- ✅ Extend LVM storage

### Step 3: Verify Storage
```bash
# Check storage
df -h
vgs
lvs

# You should see increased space available
```

## Main Deployment

### Step 4: Stop Old Service (if running)
```bash
# Stop any running PaaS service
systemctl stop proxmox-paas 2>/dev/null || true
pkill -f "app.py" 2>/dev/null || true
pkill -f "app-lxc" 2>/dev/null || true
```

### Step 5: Backup and Update Application
```bash
# Backup old version
cp /root/proxmox-paas/app.py /root/proxmox-paas/app.py.backup 2>/dev/null || true

# Copy new optimized version
cp /root/app-final-optimized.py /root/proxmox-paas/app.py

# Ensure templates exist
ls -la /root/proxmox-paas/templates/index.html

# If not, upload it
# scp templates-enhanced/index.html root@192.168.171.140:/root/proxmox-paas/templates/
```

### Step 6: Restart Service
```bash
# Reload systemd
systemctl daemon-reload

# Restart PaaS platform
systemctl restart proxmox-paas

# Check status
systemctl status proxmox-paas

# View logs
journalctl -u proxmox-paas -f
```

### Step 7: Verify API
```bash
# Test API
curl http://localhost:5000/frameworks

# Should return JSON with all 10 frameworks
```

## Deploy All Test Frameworks

### Step 8: Access Web Interface
Open browser: **http://192.168.171.140:5000**

### Step 9: Deploy Each Framework

The system now prevents ID and IP conflicts automatically!

#### 1. Python Flask (CT 300)
```
Name: test-flask
Repo: https://github.com/mouones/test
Framework: Python Flask 🐍
Type: LXC
Deploy!
Expected: http://192.168.171.200:8000
```

#### 2. Python Django (CT 301)
```
Name: test-django
Repo: https://github.com/mouones/test
Framework: Python Django 🎸
Type: LXC
Deploy!
Expected: http://192.168.171.201:8000
```

#### 3. Python FastAPI (CT 302)
```
Name: test-fastapi
Repo: https://github.com/mouones/test
Framework: Python FastAPI ⚡
Type: LXC
Deploy!
Expected: http://192.168.171.202:8000
```

#### 4. Node.js Express (CT 303)
```
Name: test-express
Repo: https://github.com/mouones/test
Framework: Node.js Express 📗
Type: LXC
Deploy!
Expected: http://192.168.171.203:3000
```

#### 5. Next.js (CT 304)
```
Name: test-nextjs
Repo: https://github.com/mouones/test
Framework: Next.js ▲
Type: LXC
Deploy!
Expected: http://192.168.171.204:3000
```

#### 6. PHP Laravel (CT 305)
```
Name: test-laravel
Repo: https://github.com/mouones/test
Framework: PHP Laravel 🔴
Type: LXC
Deploy!
Expected: http://192.168.171.205:8000
```

#### 7. Go Gin (CT 306)
```
Name: test-go
Repo: https://github.com/mouones/test
Framework: Go Gin 🐹
Type: LXC
Deploy!
Expected: http://192.168.171.206:8080
```

#### 8. Rust Actix (CT 307)
```
Name: test-rust
Repo: https://github.com/mouones/test
Framework: Rust Actix 🦀
Type: LXC
Deploy!
Expected: http://192.168.171.207:8080
```

#### 9. Ruby on Rails (CT 308)
```
Name: test-ruby
Repo: https://github.com/mouones/test
Framework: Ruby on Rails 💎
Type: LXC
Deploy!
Expected: http://192.168.171.208:3000
```

#### 10. Static Site (CT 309)
```
Name: test-static
Repo: https://github.com/mouones/test
Framework: Static Site (Nginx) 🌐
Type: LXC
Deploy!
Expected: http://192.168.171.209:80
```

## Automated Batch Deployment

### Option: Deploy All at Once via API
```bash
curl -X POST http://192.168.171.140:5000/deploy-all-tests \
  -H "Content-Type: application/json"
```

This will deploy all 10 frameworks automatically!

## Verification

### Check All Containers
```bash
pct list

# Should show:
# VMID  Status   Name
# 300   running  test-flask
# 301   running  test-django
# 302   running  test-fastapi
# 303   running  test-express
# 304   running  test-nextjs
# 305   running  test-laravel
# 306   running  test-go
# 307   running  test-rust
# 308   running  test-ruby
# 309   running  test-static
```

### Test Each Application
```bash
# Test Flask
curl http://192.168.171.200:8000

# Test Django
curl http://192.168.171.201:8000

# Test FastAPI
curl http://192.168.171.202:8000

# Test Express
curl http://192.168.171.203:3000

# Test Next.js
curl http://192.168.171.204:3000

# Test Laravel
curl http://192.168.171.205:8000

# Test Go
curl http://192.168.171.206:8080

# Test Rust
curl http://192.168.171.207:8080

# Test Ruby
curl http://192.168.171.208:3000

# Test Static
curl http://192.168.171.209:80
```

### Check Container Resources
```bash
# View all container IPs
for ctid in $(pct list | awk 'NR>1{print $1}'); do
  echo "=== CT $ctid ==="
  pct config $ctid | grep "net0"
  pct exec $ctid -- systemctl list-units --type=service --state=running | grep -v "systemd"
  echo ""
done
```

## Conflict Prevention Features

### Automatic ID Management
- ✅ Checks both containers AND VMs
- ✅ Finds next available ID in range 300-399
- ✅ Never reuses active IDs

### Automatic IP Management
- ✅ Scans existing container IPs
- ✅ Prevents duplicate assignments
- ✅ Finds next available IP if calculated one is taken
- ✅ IP range: 192.168.171.200-299

### Example Conflict Resolution
```
Scenario: CT 301 already exists
Action: System assigns CT 302 automatically

Scenario: IP 192.168.171.201 in use
Action: System finds next free IP (e.g., 192.168.171.210)
```

## Storage Management

### Check Storage Usage
```bash
# Overall storage
df -h

# LVM volumes
lvs

# Container disk usage
for ctid in $(pct list | awk 'NR>1{print $1}'); do
  echo "CT $ctid:"
  pct exec $ctid -- df -h | grep -E "Filesystem|/dev"
done
```

### Clean Up Old Containers
```bash
# Stop and remove specific container
pct stop 300
pct destroy 300

# Or via API
curl -X DELETE http://192.168.171.140:5000/delete/300
```

### Extend Container Disk
```bash
# Increase disk for container 301 by 5GB
pct resize 301 rootfs +5G

# Restart container
pct reboot 301
```

## Monitoring

### Real-Time Logs
```bash
# PaaS platform logs
journalctl -u proxmox-paas -f

# Specific container app logs
pct exec 301 -- journalctl -u test-django -f

# All container logs
for ctid in $(pct list | awk 'NR>1{print $1}'); do
  echo "=== CT $ctid ==="
  pct exec $ctid -- journalctl -n 20 --no-pager
done
```

### Performance Monitoring
```bash
# System resources
htop

# Container resources
pct status 301

# Network connections
ss -tulnp | grep -E "5000|8000|3000|8080"
```

## Troubleshooting

### Container Won't Start
```bash
# Check logs
pct status 301
journalctl -u proxmox-paas | grep "301"

# Check disk space
df -h
lvs

# Try manual start
pct start 301
pct enter 301
```

### App Not Responding
```bash
# Enter container
pct enter 301

# Check service
systemctl status test-django

# Restart service
systemctl restart test-django

# Check logs
journalctl -u test-django -n 50
```

### IP Conflict
```bash
# The system now prevents this automatically!
# But if it happens:

# Check current IPs
for ctid in $(pct list | awk 'NR>1{print $1}'); do
  echo -n "CT $ctid: "
  pct config $ctid | grep "ip=" | grep -oP '\d+\.\d+\.\d+\.\d+'
done

# Manually change IP if needed
pct set 301 -net0 name=eth0,bridge=vmbr0,ip=192.168.171.210/24,gw=192.168.171.2
pct reboot 301
```

### Out of Disk Space
```bash
# Run storage optimization again
./optimize-storage.sh

# Remove old containers
pct destroy 300

# Clean logs
journalctl --vacuum-time=3d
```

## Success Criteria

All tests pass when:
- ✅ All 10 containers created (300-309)
- ✅ All have unique IPs (200-209)
- ✅ All services running
- ✅ All apps accessible via HTTP
- ✅ No ID or IP conflicts
- ✅ Storage optimized
- ✅ Platform stable

## Expected Results

### Container Summary
```
CT 300: test-flask      → 192.168.171.200:8000 (Python Flask)
CT 301: test-django     → 192.168.171.201:8000 (Python Django)
CT 302: test-fastapi    → 192.168.171.202:8000 (Python FastAPI)
CT 303: test-express    → 192.168.171.203:3000 (Node.js Express)
CT 304: test-nextjs     → 192.168.171.204:3000 (Next.js)
CT 305: test-laravel    → 192.168.171.205:8000 (PHP Laravel)
CT 306: test-go         → 192.168.171.206:8080 (Go Gin)
CT 307: test-rust       → 192.168.171.207:8080 (Rust Actix)
CT 308: test-ruby       → 192.168.171.208:3000 (Ruby on Rails)
CT 309: test-static     → 192.168.171.209:80   (Static Nginx)
```

### Total Resources Used
- **Storage:** ~80GB (8GB × 10 containers)
- **Memory:** ~20GB (2GB × 10 containers)
- **IPs:** 10 (192.168.171.200-209)
- **Container IDs:** 10 (300-309)

## Maintenance

### Daily Checks
```bash
# Check all containers
pct list

# Check service
systemctl status proxmox-paas

# Check logs
journalctl -u proxmox-paas -n 20
```

### Weekly Tasks
```bash
# Update system
apt-get update && apt-get upgrade -y

# Clean old logs
journalctl --vacuum-time=7d

# Check storage
df -h && lvs
```

### Monthly Tasks
```bash
# Full optimization
./optimize-storage.sh

# Backup configuration
tar -czf paas-backup-$(date +%Y%m%d).tar.gz /root/proxmox-paas/

# Backup containers
for ctid in $(pct list | awk 'NR>1{print $1}'); do
  vzdump $ctid --storage local
done
```

---

## Summary

You now have:
- ✅ Optimized storage (120GB added)
- ✅ Conflict-free ID management
- ✅ Conflict-free IP assignment
- ✅ 10 test frameworks deployed
- ✅ All applications accessible
- ✅ Production-ready platform

**Access Point:** http://192.168.171.140:5000

**Ready to deploy your own apps!** 🚀

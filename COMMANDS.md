# 🎯 Quick Command Reference - Proxmox PaaS Platform

## 📍 System Access

```bash
# SSH to Proxmox
ssh root@192.168.171.140

# Web Interface
http://192.168.171.140:5000

# Proxmox Admin
https://192.168.171.140:8006
```

---

## 🚀 Deploy Applications

### Via Web Interface
```
1. Open: http://192.168.171.140:5000
2. Select framework from dropdown
3. Enter container name
4. Enter GitHub repo URL (or use default test repo)
5. Click "Deploy!"
6. Wait 2-5 minutes
7. Access at: http://192.168.171.<IP>:<PORT>
```

### Via API - Single Deployment
```bash
curl -X POST http://192.168.171.140:5000/deploy \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-app",
    "repo": "https://github.com/username/repo",
    "framework": "python-flask",
    "type": "lxc"
  }'
```

### Via API - Deploy All Test Frameworks
```bash
# Deploy all 10 frameworks at once
curl -X POST http://192.168.171.140:5000/deploy-all-tests
```

---

## 📊 Check Status

### List All Containers
```bash
ssh root@192.168.171.140 "pct list"
```

### Check Specific Container
```bash
# Get container status
curl http://192.168.171.140:5000/status/<ctid>

# Example:
curl http://192.168.171.140:5000/status/300
```

### View Container Details
```bash
ssh root@192.168.171.140 "pct config <ctid>"
```

### Test Application Access
```bash
# Flask (port 8000)
curl http://192.168.171.200:8000

# Express (port 3000)
curl http://192.168.171.201:3000

# Next.js (port 3000)
curl http://192.168.171.204:3000

# Go Gin (port 8080)
curl http://192.168.171.206:8080
```

---

## 🔍 Monitoring

### PaaS Platform Logs
```bash
ssh root@192.168.171.140 "tail -f /tmp/paas.log"
```

### Container Logs
```bash
ssh root@192.168.171.140 "pct exec <ctid> -- journalctl -u <service> -f"

# Examples:
pct exec 300 -- journalctl -u flask-app -f
pct exec 301 -- journalctl -u express-app -f
```

### View Container Console
```bash
ssh root@192.168.171.140 "pct enter <ctid>"
```

### Check Running Services
```bash
ssh root@192.168.171.140 "pct exec <ctid> -- systemctl list-units --type=service --state=running"
```

---

## 💾 Storage Management

### Check Storage Usage
```bash
ssh root@192.168.171.140 "df -h; echo '---'; lvs"
```

### Optimize Storage
```bash
ssh root@192.168.171.140 "/root/optimize-storage.sh"
```

### Check Container Disk Usage
```bash
ssh root@192.168.171.140 "pct exec <ctid> -- df -h"
```

### Resize Container Disk
```bash
ssh root@192.168.171.140 "pct resize <ctid> rootfs +5G"
```

---

## 🛠️ Container Management

### Start Container
```bash
ssh root@192.168.171.140 "pct start <ctid>"
```

### Stop Container
```bash
ssh root@192.168.171.140 "pct stop <ctid>"
```

### Restart Container
```bash
ssh root@192.168.171.140 "pct reboot <ctid>"
```

### Delete Container
```bash
# Via API
curl -X DELETE http://192.168.171.140:5000/delete/<ctid>

# Via SSH
ssh root@192.168.171.140 "pct stop <ctid> && pct destroy <ctid>"
```

---

## 🔧 PaaS Management

### Check PaaS Status
```bash
ssh root@192.168.171.140 "ss -tlnp | grep 5000"
```

### Restart PaaS Platform
```bash
ssh root@192.168.171.140 "pkill -f 'proxmox-paas/app.py'; cd /root/proxmox-paas && python3 app.py > /tmp/paas.log 2>&1 &"
```

### View PaaS Logs
```bash
ssh root@192.168.171.140 "tail -100 /tmp/paas.log"
```

### Test PaaS API
```bash
# List frameworks
curl http://192.168.171.140:5000/frameworks

# List containers
curl http://192.168.171.140:5000/containers
```

---

## 🌐 Network Management

### Check Container IPs
```bash
ssh root@192.168.171.140 "
for ctid in \$(pct list | awk 'NR>1{print \$1}'); do
  echo -n \"CT \$ctid: \"
  pct config \$ctid | grep 'ip=' | grep -oP '\d+\.\d+\.\d+\.\d+'
done
"
```

### Test Network Connectivity
```bash
ssh root@192.168.171.140 "pct exec <ctid> -- ping -c 3 8.8.8.8"
```

### Check Port Usage
```bash
ssh root@192.168.171.140 "ss -tulnp | grep -E '5000|8000|3000|8080'"
```

---

## 📦 Backup & Restore

### Backup Single Container
```bash
ssh root@192.168.171.140 "vzdump <ctid> --storage local"
```

### Backup All Containers
```bash
ssh root@192.168.171.140 "
for ctid in \$(pct list | awk 'NR>1{print \$1}'); do
  vzdump \$ctid --storage local
done
"
```

### List Backups
```bash
ssh root@192.168.171.140 "ls -lh /var/lib/vz/dump/"
```

### Restore Container
```bash
ssh root@192.168.171.140 "pct restore <new-ctid> /var/lib/vz/dump/vzdump-lxc-<ctid>-*.tar.zst"
```

---

## 🧹 Cleanup Operations

### Remove Failed Deployments
```bash
# Find stopped containers
ssh root@192.168.171.140 "pct list | grep stopped"

# Remove specific container
ssh root@192.168.171.140 "pct destroy <ctid>"
```

### Clean Old Logs
```bash
ssh root@192.168.171.140 "journalctl --vacuum-time=7d"
```

### Clean APT Cache
```bash
ssh root@192.168.171.140 "apt-get clean && apt-get autoclean"
```

### Remove Orphaned Disks
```bash
ssh root@192.168.171.140 "/root/optimize-storage.sh"
```

---

## 📈 Batch Operations

### Deploy All 10 Test Frameworks
```bash
curl -X POST http://192.168.171.140:5000/deploy-all-tests \
  -H "Content-Type: application/json"

# This will create:
# CT 303: Flask test
# CT 304: Django test
# CT 305: FastAPI test
# CT 306: Express test
# CT 307: Next.js test
# CT 308: Laravel test
# CT 309: Go Gin test
# CT 310: Rust Actix test
# CT 311: Ruby Rails test
# CT 312: Static Nginx test
```

### Start All Containers
```bash
ssh root@192.168.171.140 "
for ctid in \$(pct list | awk 'NR>1{print \$1}'); do
  pct start \$ctid
done
"
```

### Stop All Containers
```bash
ssh root@192.168.171.140 "
for ctid in \$(pct list | awk 'NR>1{print \$1}'); do
  pct stop \$ctid
done
"
```

### Check All Container Status
```bash
ssh root@192.168.171.140 "
for ctid in \$(pct list | awk 'NR>1{print \$1}'); do
  echo \"=== CT \$ctid ===\"
  pct status \$ctid
  pct config \$ctid | grep -E 'hostname|ip='
  echo \"\"
done
"
```

---

## 🔍 Troubleshooting Commands

### PaaS Won't Start
```bash
# Kill any conflicting process
ssh root@192.168.171.140 "pkill -9 -f python; sleep 2; cd /root/proxmox-paas && python3 app.py > /tmp/paas.log 2>&1 &"

# Check if started
ssh root@192.168.171.140 "ss -tlnp | grep 5000"
```

### Container Won't Start
```bash
# Check status
ssh root@192.168.171.140 "pct status <ctid>"

# Check logs
ssh root@192.168.171.140 "journalctl | grep 'pct\[' | tail -50"

# Try force start
ssh root@192.168.171.140 "pct start <ctid> --force"
```

### Out of Space
```bash
# Check space
ssh root@192.168.171.140 "df -h && lvs"

# Run optimization
ssh root@192.168.171.140 "/root/optimize-storage.sh"

# Remove old containers
ssh root@192.168.171.140 "pct destroy <old-ctid>"
```

### Application Not Responding
```bash
# Enter container
ssh root@192.168.171.140 "pct enter <ctid>"

# Inside container:
systemctl status <app-service>
systemctl restart <app-service>
journalctl -u <app-service> -n 50
curl http://localhost:<port>
```

---

## 📝 Framework-Specific Commands

### Python Applications (Flask/Django/FastAPI)
```bash
# Inside container
cd /opt/app
source venv/bin/activate
python app.py
```

### Node.js Applications (Express/Next.js)
```bash
# Inside container
cd /opt/app
npm start
# or
node app.js
```

### PHP Laravel
```bash
# Inside container
cd /opt/app
php artisan serve --host=0.0.0.0 --port=8000
```

### Go Application
```bash
# Inside container
cd /opt/app
go run main.go
# or
./app
```

### Rust Application
```bash
# Inside container
cd /opt/app
cargo run
# or
./target/release/app
```

### Ruby on Rails
```bash
# Inside container
cd /opt/app
bundle exec rails server -b 0.0.0.0
```

---

## 🎨 One-Liner Commands

### Quick Status Check
```bash
ssh root@192.168.171.140 "pct list; echo '---'; ss -tlnp | grep -E '5000|8000|3000|8080'; echo '---'; df -h | grep -E 'Filesystem|pve-root'"
```

### Deploy Flask Test
```bash
curl -X POST http://192.168.171.140:5000/deploy -H "Content-Type: application/json" -d '{"name":"test-flask","repo":"https://github.com/mouones/test","framework":"python-flask","type":"lxc"}'
```

### Check All Apps
```bash
for ip in {200..210}; do echo "=== 192.168.171.$ip ==="; curl -s -m 2 http://192.168.171.$ip:8000 2>&1 | head -5; curl -s -m 2 http://192.168.171.$ip:3000 2>&1 | head -5; done
```

### Full System Status
```bash
ssh root@192.168.171.140 "echo '=== CONTAINERS ==='; pct list; echo '=== STORAGE ==='; df -h | grep pve; echo '=== PAAS ==='; ss -tlnp | grep 5000; echo '=== MEMORY ==='; free -h"
```

---

## 💡 Pro Tips

### Monitor Deployment in Real-Time
```bash
ssh root@192.168.171.140 "tail -f /tmp/paas.log"
```

### Quick Container Shell Access
```bash
ssh -t root@192.168.171.140 "pct enter <ctid>"
```

### Check What Framework is Running
```bash
ssh root@192.168.171.140 "pct exec <ctid> -- ps aux | grep -E 'python|node|php|go|ruby'"
```

### Find Container by Name
```bash
ssh root@192.168.171.140 "pct list | grep '<name>'"
```

### Copy Files to Container
```bash
# From Proxmox host
ssh root@192.168.171.140 "pct push <ctid> /path/to/local/file /path/in/container/file"
```

### Copy Files from Container
```bash
# To Proxmox host
ssh root@192.168.171.140 "pct pull <ctid> /path/in/container/file /path/to/local/file"
```

---

## 📚 Common Workflows

### Workflow 1: Deploy New App
```bash
# 1. Open web interface
http://192.168.171.140:5000

# 2. Or use API
curl -X POST http://192.168.171.140:5000/deploy \
  -H "Content-Type: application/json" \
  -d '{"name":"my-app","repo":"https://github.com/user/repo","framework":"python-flask","type":"lxc"}'

# 3. Check status
curl http://192.168.171.140:5000/containers

# 4. Test app
curl http://192.168.171.<next-ip>:8000
```

### Workflow 2: Troubleshoot Failed Deployment
```bash
# 1. Check logs
ssh root@192.168.171.140 "tail -100 /tmp/paas.log"

# 2. Check container
ssh root@192.168.171.140 "pct list | grep <name>"

# 3. Enter container
ssh root@192.168.171.140 "pct enter <ctid>"

# 4. Check service inside
systemctl status <service-name>
journalctl -u <service-name> -n 50

# 5. Fix and restart
systemctl restart <service-name>
```

### Workflow 3: Clean and Optimize
```bash
# 1. Run optimization
ssh root@192.168.171.140 "/root/optimize-storage.sh"

# 2. Remove old containers
ssh root@192.168.171.140 "pct list | grep stopped"
ssh root@192.168.171.140 "pct destroy <old-ctid>"

# 3. Clean logs
ssh root@192.168.171.140 "journalctl --vacuum-time=7d"

# 4. Check space
ssh root@192.168.171.140 "df -h && lvs"
```

---

## 🎯 Quick Test Suite

### Test All Components
```bash
# Test 1: PaaS API
curl http://192.168.171.140:5000/frameworks

# Test 2: Container list
curl http://192.168.171.140:5000/containers

# Test 3: Storage
ssh root@192.168.171.140 "df -h | grep pve"

# Test 4: Network
ssh root@192.168.171.140 "ss -tlnp | grep 5000"

# Test 5: Container status
ssh root@192.168.171.140 "pct list"
```

---

## 🚀 Production Checklist

Before going to production:

```bash
# 1. Security
ssh root@192.168.171.140 "passwd"  # Change root password

# 2. Firewall
ssh root@192.168.171.140 "pve-firewall status"

# 3. Backups
ssh root@192.168.171.140 "crontab -e"
# Add: 0 2 * * * vzdump --all --storage local

# 4. Updates
ssh root@192.168.171.140 "apt-get update && apt-get upgrade -y"

# 5. Monitoring
ssh root@192.168.171.140 "systemctl status pve*"
```

---

**Last Updated:** December 2, 2024
**System Version:** Proxmox PaaS Platform v2.0 Enhanced
**Status:** 🟢 Operational

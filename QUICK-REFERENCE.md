# 🚀 Proxmox PaaS - Quick Reference Card

## 📍 Access Points

| Service | URL | Description |
|---------|-----|-------------|
| **Web Interface** | http://192.168.171.140:5000 | Main deployment UI |
| **API Endpoint** | http://192.168.171.140:5000/deploy | REST API |
| **Frameworks** | http://192.168.171.140:5000/frameworks | List frameworks |
| **Container List** | http://192.168.171.140:5000/list | List containers |

## 🎨 Supported Frameworks

```
🐍 Python Flask       → Port 8000  → app.py
🎸 Python Django      → Port 8000  → manage.py
⚡ Python FastAPI     → Port 8000  → main.py
📗 Node.js Express    → Port 3000  → app.js
▲  Next.js            → Port 3000  → package.json
🔴 PHP Laravel        → Port 8000  → artisan
🐹 Go Gin             → Port 8080  → main.go
🦀 Rust Actix         → Port 8080  → Cargo.toml
💎 Ruby on Rails      → Port 3000  → Gemfile
🌐 Static Sites       → Port 80    → index.html
```

## ⚡ Quick Commands

### Service Management
```bash
systemctl start proxmox-paas      # Start service
systemctl stop proxmox-paas       # Stop service
systemctl restart proxmox-paas    # Restart service
systemctl status proxmox-paas     # Check status
journalctl -u proxmox-paas -f     # View logs
```

### Container Management
```bash
pct list                          # List all containers
pct status 301                    # Check container status
pct start 301                     # Start container
pct stop 301                      # Stop container
pct enter 301                     # Enter container shell
pct destroy 301                   # Delete container
```

### Debugging
```bash
# Check app logs in container
pct exec 301 -- journalctl -u my-app -f

# Check container network
pct exec 301 -- ip addr show

# Check app process
pct exec 301 -- ps aux | grep python

# Test app locally
pct exec 301 -- curl localhost:8000

# Check listening ports
pct exec 301 -- ss -tlnp
```

## 📡 API Usage

### Deploy Application
```bash
curl -X POST http://192.168.171.140:5000/deploy \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-app",
    "repo": "https://github.com/user/repo",
    "framework": "python-flask",
    "type": "lxc"
  }'
```

### List Containers
```bash
curl http://192.168.171.140:5000/list
```

### Get Container Status
```bash
curl http://192.168.171.140:5000/status/301
```

### Delete Container
```bash
curl -X DELETE http://192.168.171.140:5000/delete/301
```

### List Available Frameworks
```bash
curl http://192.168.171.140:5000/frameworks
```

## 🔧 Configuration Files

```
/root/proxmox-paas/
├── app.py                          # Main API application
├── templates/
│   └── index.html                  # Web interface
├── venv/                           # Python virtual environment
└── logs/                           # Application logs

/etc/systemd/system/
└── proxmox-paas.service            # Systemd service file

/var/lib/vz/template/cache/
└── ubuntu-22.04-standard_*.tar.zst # LXC template
```

## 📊 Default Settings

| Setting | Value |
|---------|-------|
| **Container ID Range** | 300-399 |
| **IP Range** | 192.168.171.200-299 |
| **Memory per Container** | 2GB |
| **CPU Cores** | 2 |
| **Disk Size** | 8GB |
| **Network** | Static IP |
| **Gateway** | 192.168.171.2 |
| **Default Password** | rootpass123 |

## 🎯 Common Tasks

### Deploy Flask App
```
1. Open http://192.168.171.140:5000
2. Name: my-flask-app
3. Repo: https://github.com/mouones/test
4. Select: Python Flask 🐍
5. Type: LXC Container
6. Click: Deploy Application
7. Wait: 60-90 seconds
8. Access: http://192.168.171.200:8000
```

### Deploy Django App
```
1. Select: Python Django 🎸
2. Repo must have: manage.py, requirements.txt
3. Auto runs: migrations
4. Port: 8000
```

### Deploy Node.js App
```
1. Select: Node.js Express 📗
2. Repo must have: package.json, app.js
3. Auto runs: npm install
4. Port: 3000
```

### Deploy Static Site
```
1. Select: Static Sites 🌐
2. Repo: HTML/CSS/JS files
3. Auto serves with: Nginx
4. Port: 80
```

## 🐛 Troubleshooting

### Service Won't Start
```bash
journalctl -u proxmox-paas -n 100  # Check logs
ss -tlnp | grep 5000               # Check if port is free
```

### Web Interface Not Loading
```bash
ls -la /root/proxmox-paas/templates/index.html  # Verify template
curl http://localhost:5000/                     # Test locally
```

### Deployment Fails
```bash
pct list                           # Check containers
df -h                              # Check disk space
pveam list local                   # Check template
```

### Container No Network
```bash
pct exec 301 -- ip addr            # Check IP
pct exec 301 -- ping 8.8.8.8       # Test connectivity
```

### App Not Responding
```bash
pct exec 301 -- systemctl status my-app        # Check service
pct exec 301 -- journalctl -u my-app -n 50    # Check logs
pct exec 301 -- ps aux | grep python           # Check process
```

## 📈 Resource Scaling

### Increase Container Resources
```bash
pct set 301 --memory 4096          # Increase RAM to 4GB
pct set 301 --cores 4              # Increase CPU to 4 cores
pct resize 301 rootfs +10G         # Add 10GB disk
pct reboot 301                     # Apply changes
```

### Increase Service Workers
```bash
# Edit /etc/systemd/system/proxmox-paas.service
# Change: --workers 4 to --workers 8
systemctl daemon-reload
systemctl restart proxmox-paas
```

## 🔐 Security

### Change Default Password
```bash
# Edit /root/proxmox-paas/app.py
# Change: PASSWORD = "rootpass123"
# To: PASSWORD = "your-secure-password"
systemctl restart proxmox-paas
```

### Enable Firewall
```bash
# Allow only from local network
iptables -A INPUT -p tcp --dport 5000 -s 192.168.171.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 5000 -j DROP
```

## 📦 Backup & Restore

### Backup Platform
```bash
tar -czf paas-backup.tar.gz /root/proxmox-paas/
cp /etc/systemd/system/proxmox-paas.service ~/proxmox-paas.service.bak
```

### Backup Container
```bash
vzdump 301 --mode snapshot --storage local
```

### Restore Container
```bash
pct restore 301 /var/lib/vz/dump/vzdump-lxc-301-*.tar.gz
```

## 📞 Support Resources

| Resource | Location |
|----------|----------|
| **Installation Guide** | INSTALLATION.md |
| **Complete Documentation** | README.md |
| **Deployment Checklist** | CHECKLIST.md |
| **Comparison Guide** | COMPARISON.md |
| **Summary** | SUMMARY.md |
| **Troubleshooting** | PROXMOX-LXC-PAAS.md |

## 🎓 Example Repositories

```bash
# Python Flask
https://github.com/mouones/test

# Python Django
git clone https://github.com/django/django-tutorial.git

# Node.js Express
git clone https://github.com/expressjs/express-sample.git

# Static Site
git clone https://github.com/username/portfolio.git
```

## 💡 Tips & Tricks

### Quick Deploy
```bash
# One-liner API deploy
curl -X POST http://192.168.171.140:5000/deploy \
  -H "Content-Type: application/json" \
  -d '{"name":"app","repo":"https://github.com/mouones/test","framework":"python-flask","type":"lxc"}'
```

### Mass Container Check
```bash
# Check all containers
for ctid in $(pct list | awk 'NR>1{print $1}'); do
  echo "=== CT $ctid ==="
  pct status $ctid
done
```

### Watch Logs Real-time
```bash
# Service logs
journalctl -u proxmox-paas -f

# Container app logs
watch -n 2 'pct exec 301 -- journalctl -u my-app -n 20'
```

### Quick Health Check
```bash
# Check everything
systemctl status proxmox-paas && \
pct list && \
df -h && \
free -h
```

## 🎯 Framework-Specific Notes

### Python Apps
- Always include `requirements.txt`
- Virtual environment created automatically
- Flask: needs `app.py` with `app.run(host='0.0.0.0', port=8000)`
- Django: needs `manage.py` and `settings.py`

### Node.js Apps
- Must have `package.json`
- npm install runs automatically
- Express: needs `app.js` or `server.js`
- Next.js: `npm build` runs automatically

### PHP Laravel
- Composer install runs automatically
- `.env` created from `.env.example`
- `php artisan key:generate` runs automatically
- Migrations not run by default

### Go/Rust
- Binary compiled during setup
- Release mode for production
- Takes longer (5-10 min)

### Static Sites
- Nginx installed and configured
- Supports: dist/, build/, public/ directories
- Falls back to root directory

## 📊 Monitoring Commands

```bash
# System resources
htop

# Network connections
ss -tulnp

# Disk usage
ncdu /var/lib/vz

# Container resources
pct exec 301 -- free -h
pct exec 301 -- df -h

# Process tree
pct exec 301 -- pstree
```

---

**Quick Help:** See README.md | **Issues:** Check TROUBLESHOOTING section
**Version:** 2.0.0 | **Updated:** December 2, 2025

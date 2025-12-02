# Complete Proxmox PaaS Setup - All-in-One Guide

## 🎯 Goal
Set up everything on Proxmox server as the main platform with 10+ framework support.

## 📋 Prerequisites
- Proxmox VE 6.14+ running at 192.168.171.140
- SSH access to Proxmox as root
- Network: 192.168.171.0/24

## 🚀 Quick Installation (Automated)

### Step 1: Upload Files to Proxmox

```powershell
# From your Windows workstation
scp install-proxmox.sh root@192.168.171.140:/root/
scp templates-enhanced/index.html root@192.168.171.140:/root/
```

### Step 2: Run Installation Script

```bash
# SSH to Proxmox
ssh root@192.168.171.140

# Make script executable and run
chmod +x /root/install-proxmox.sh
/root/install-proxmox.sh
```

### Step 3: Upload Web Template

```bash
# Move the HTML template
mkdir -p /root/proxmox-paas/templates
mv /root/index.html /root/proxmox-paas/templates/
```

### Step 4: Restart Service

```bash
systemctl restart proxmox-paas
```

### Step 5: Access Platform

Open browser: **http://192.168.171.140:5000**

## 🛠️ Manual Installation (Step by Step)

### 1. SSH to Proxmox

```bash
ssh root@192.168.171.140
```

### 2. Install Dependencies

```bash
apt-get update
apt-get install -y python3 python3-pip python3-venv git curl
```

### 3. Create Installation Directory

```bash
mkdir -p /root/proxmox-paas/templates
cd /root/proxmox-paas
```

### 4. Setup Python Environment

```bash
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install flask requests gunicorn
```

### 5. Download LXC Template

```bash
pveam update
pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst
```

### 6. Create Application Files

Upload these files from your Windows machine:
- `app-lxc-enhanced.py` → `/root/proxmox-paas/app.py`
- `templates-enhanced/index.html` → `/root/proxmox-paas/templates/index.html`

Or copy content manually using vi/nano.

### 7. Create Systemd Service

```bash
cat > /etc/systemd/system/proxmox-paas.service << 'EOF'
[Unit]
Description=Proxmox PaaS Platform
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/proxmox-paas
Environment="PATH=/root/proxmox-paas/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/root/proxmox-paas/venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 4 --timeout 300 app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
```

### 8. Enable and Start Service

```bash
systemctl daemon-reload
systemctl enable proxmox-paas
systemctl start proxmox-paas
systemctl status proxmox-paas
```

## ✅ Verification

### Check Service Status

```bash
systemctl status proxmox-paas
```

Should show: **Active: active (running)**

### View Logs

```bash
journalctl -u proxmox-paas -f
```

### Test API

```bash
curl http://localhost:5000/frameworks
```

Should return JSON with all frameworks.

### Test Web Interface

```bash
curl http://localhost:5000/
```

Should return HTML content.

## 🌐 Access from Windows

Open browser to: **http://192.168.171.140:5000**

You should see the modern PaaS web interface with:
- Framework selection (10+ frameworks)
- Deployment form
- Running containers list
- Statistics dashboard

## 📦 Supported Frameworks

| Framework | Icon | Port | Language |
|-----------|------|------|----------|
| Python Flask | 🐍 | 8000 | Python |
| Python Django | 🎸 | 8000 | Python |
| Python FastAPI | ⚡ | 8000 | Python |
| Node.js Express | 📗 | 3000 | JavaScript |
| Next.js | ▲ | 3000 | JavaScript |
| PHP Laravel | 🔴 | 8000 | PHP |
| Go Gin | 🐹 | 8080 | Go |
| Rust Actix | 🦀 | 8080 | Rust |
| Ruby on Rails | 💎 | 3000 | Ruby |
| Static Site | 🌐 | 80 | HTML/CSS/JS |

## 🎯 Deploy Your First App

### Via Web Interface

1. Open http://192.168.171.140:5000
2. Enter app name: `my-flask-app`
3. Enter repo: `https://github.com/mouones/test`
4. Select framework: **Python Flask 🐍**
5. Choose type: **LXC Container**
6. Click **Deploy Application**
7. Wait 60-90 seconds
8. Access your app at the provided URL

### Via API (curl)

```bash
curl -X POST http://192.168.171.140:5000/deploy \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-app",
    "repo": "https://github.com/mouones/test",
    "framework": "python-flask",
    "type": "lxc"
  }'
```

### Via PowerShell

```powershell
$body = @{
    name = "my-app"
    repo = "https://github.com/mouones/test"
    framework = "python-flask"
    type = "lxc"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://192.168.171.140:5000/deploy" `
    -Method Post `
    -ContentType "application/json" `
    -Body $body
```

## 🔧 Service Management

### Start Service
```bash
systemctl start proxmox-paas
```

### Stop Service
```bash
systemctl stop proxmox-paas
```

### Restart Service
```bash
systemctl restart proxmox-paas
```

### View Status
```bash
systemctl status proxmox-paas
```

### View Live Logs
```bash
journalctl -u proxmox-paas -f
```

### View Last 100 Lines
```bash
journalctl -u proxmox-paas -n 100
```

## 🐛 Troubleshooting

### Service Won't Start

```bash
# Check logs
journalctl -u proxmox-paas -n 50

# Check if port is in use
ss -tlnp | grep 5000

# Verify Python environment
/root/proxmox-paas/venv/bin/python --version
/root/proxmox-paas/venv/bin/pip list

# Test app manually
cd /root/proxmox-paas
source venv/bin/activate
python app.py
```

### Web Interface Not Loading

```bash
# Check if service is running
systemctl status proxmox-paas

# Check if templates directory exists
ls -la /root/proxmox-paas/templates/

# Verify index.html exists
cat /root/proxmox-paas/templates/index.html | head -n 10
```

### Deployment Fails

```bash
# Check container creation
pct list

# Check last container logs
journalctl -u proxmox-paas | tail -n 100

# Verify LXC template exists
ls -lh /var/lib/vz/template/cache/

# Test container creation manually
pct create 999 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname test \
  --memory 2048 \
  --cores 2 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.171.199/24,gw=192.168.171.2
```

### Cannot Access from Windows

```bash
# Check firewall on Proxmox
iptables -L -n | grep 5000

# Test locally on Proxmox
curl http://localhost:5000/

# Check if service is listening on all interfaces
ss -tlnp | grep 5000
```

If you see `127.0.0.1:5000`, the service is only listening locally. Should be `0.0.0.0:5000`.

## 🔒 Security Hardening

### Change Default Password

Edit `/root/proxmox-paas/app.py`:

```python
PASSWORD = "your-secure-password-here"
```

Then restart:
```bash
systemctl restart proxmox-paas
```

### Add Firewall Rules

```bash
# Allow only from specific network
iptables -A INPUT -p tcp --dport 5000 -s 192.168.171.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 5000 -j DROP

# Save rules
iptables-save > /etc/iptables/rules.v4
```

### Enable HTTPS (Optional)

```bash
# Install nginx
apt-get install -y nginx certbot python3-certbot-nginx

# Configure as reverse proxy with SSL
cat > /etc/nginx/sites-available/paas << 'EOF'
server {
    listen 443 ssl http2;
    server_name paas.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/paas.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/paas.yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

ln -s /etc/nginx/sites-available/paas /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
```

## 📊 Monitoring

### Check Container Resources

```bash
# List all containers with resources
for ctid in $(pct list | awk 'NR>1{print $1}'); do
  echo "=== Container $ctid ==="
  pct config $ctid | grep -E "memory|cores"
  pct exec $ctid -- df -h | grep -E "Filesystem|/dev"
  echo ""
done
```

### Check Service Performance

```bash
# Service memory usage
ps aux | grep gunicorn

# System resources
free -h
df -h
```

## 🎓 Example Repositories

Test these repositories with different frameworks:

### Python Flask
```
https://github.com/mouones/test
```

### Python Django
```
https://github.com/yourusername/django-app
```

### Node.js Express
```
https://github.com/yourusername/express-app
```

### PHP Laravel
```
https://github.com/yourusername/laravel-app
```

## 📈 Scaling

### Increase Container Resources

```bash
# Increase memory and CPU
pct set 301 --memory 4096 --cores 4

# Increase disk space
pct resize 301 rootfs +10G

# Apply changes (requires restart)
pct reboot 301
```

### Add More Workers

Edit `/etc/systemd/system/proxmox-paas.service`:

```ini
ExecStart=/root/proxmox-paas/venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 8 --timeout 300 app:app
```

Restart:
```bash
systemctl daemon-reload
systemctl restart proxmox-paas
```

## 🎉 Success!

Your Proxmox PaaS platform is now fully operational!

**Access URL:** http://192.168.171.140:5000

Features:
- ✅ 10+ Framework Support
- ✅ Web Interface
- ✅ RESTful API
- ✅ Automatic Deployment
- ✅ Container Management
- ✅ Real-time Monitoring
- ✅ Auto-restart on Failure
- ✅ Boot on System Start

**Next Steps:**
1. Deploy your first application
2. Explore different frameworks
3. Set up monitoring
4. Configure backups
5. Add authentication

For support, check the main README.md and PROXMOX-LXC-PAAS.md documentation.

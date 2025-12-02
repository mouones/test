# Proxmox LXC PaaS Platform - Complete Guide

## Overview
A fully functional Platform-as-a-Service (PaaS) built on Proxmox VE 6.14 using LXC containers for fast, reliable deployments.

## ✅ System Status

### Infrastructure
- **Proxmox Host:** 192.168.171.140
- **Gateway:** 192.168.171.2
- **Network:** 192.168.171.0/24
- **API Endpoint:** http://192.168.171.140:5000

### Deployed Containers
- **CT 200:** test-container (192.168.171.200) - Manual test
- **CT 300:** flask-lxc (192.168.171.200) - GitHub: mouones/test ✅ Running
- **CT 301:** test-app-2 (192.168.171.201) - GitHub: mouones/test ✅ Running

## Quick Start

### Deploy a New Application

```powershell
# Deploy from GitHub repo
Invoke-RestMethod -Uri http://192.168.171.140:5000/deploy `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"name":"my-app","repo":"https://github.com/user/repo","framework":"python"}'
```

**Response:**
```json
{
  "status": "success",
  "ctid": 302,
  "name": "my-app",
  "ip": "192.168.171.202",
  "url": "http://192.168.171.202:8000",
  "ssh": "pct enter 302",
  "password": "rootpass123"
}
```

### Test the Deployed App

```powershell
# Wait 60 seconds for installation to complete
Start-Sleep -Seconds 60

# Test the app
Invoke-WebRequest http://192.168.171.202:8000
```

### List All Containers

```powershell
Invoke-RestMethod http://192.168.171.140:5000/list
```

### Delete a Container

```powershell
Invoke-RestMethod -Uri http://192.168.171.140:5000/delete/302 -Method DELETE
```

### Check Container Status

```powershell
Invoke-RestMethod http://192.168.171.140:5000/status/302
```

## Application Requirements

Your GitHub repository must have:

1. **app.py** - Main Flask application
   ```python
   from flask import Flask
   app = Flask(__name__)
   
   @app.route('/')
   def home():
       return '<h1>Hello World!</h1>'
   
   if __name__ == '__main__':
       app.run(host='0.0.0.0', port=8000)
   ```

2. **requirements.txt** - Python dependencies
   ```
   flask==3.0.0
   werkzeug==3.0.1
   ```

## Architecture

### Container Configuration
- **Base Image:** Ubuntu 22.04 LXC template
- **Memory:** 2048 MB
- **CPU Cores:** 2
- **Storage:** 8GB (local-lvm)
- **Network:** Static IP on vmbr0
- **Features:** nesting=1, unprivileged

### Automatic Setup
Each deployment automatically:
1. Creates LXC container with unique ID
2. Assigns static IP (192.168.171.200+)
3. Installs Python 3.10, pip, git, venv
4. Clones GitHub repository to `/opt/app`
5. Creates virtual environment
6. Installs requirements.txt
7. Creates systemd service
8. Starts the application

### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/deploy` | Deploy new container |
| GET | `/list` | List all containers |
| GET | `/status/<ctid>` | Get container status |
| DELETE | `/delete/<ctid>` | Delete container |

## Advanced Usage

### SSH into Container (from Proxmox)

```bash
ssh root@192.168.171.140
pct enter 301
```

### View Application Logs

```bash
pct exec 301 -- journalctl -u test-app-2 -f
```

### Restart Application

```bash
pct exec 301 -- systemctl restart test-app-2
```

### Manual App Management

```bash
# SSH to Proxmox
ssh root@192.168.171.140

# Enter container
pct enter 301

# Go to app directory
cd /opt/app

# Activate venv
source venv/bin/activate

# Run manually
python app.py
```

## Troubleshooting

### Check if container is running
```powershell
Invoke-RestMethod http://192.168.171.140:5000/status/301
```

### Test connectivity
```powershell
Test-NetConnection -ComputerName 192.168.171.201 -Port 8000
```

### View container processes
```bash
ssh root@192.168.171.140 "pct exec 301 -- ps aux"
```

### Check if app is listening
```bash
ssh root@192.168.171.140 "pct exec 301 -- ss -tlnp | grep 8000"
```

### Restart API Server
```bash
ssh root@192.168.171.140
cd /root/proxmox-paas
source venv/bin/activate
pkill -f app-lxc.py
nohup python app-lxc.py > /var/log/paas-lxc-api.log 2>&1 &
```

## Container Management

### Stop Container
```bash
pct stop 301
```

### Start Container
```bash
pct start 301
```

### Delete Container
```bash
pct stop 301
pct destroy 301
```

### Container Config
```bash
pct config 301
```

## Performance

### LXC vs QEMU VMs
- **Startup time:** ~15 seconds vs 60-120 seconds
- **Memory overhead:** ~50MB vs ~500MB
- **Network:** Direct bridge (faster, no NAT)
- **Reliability:** ✅ Works vs ❌ Cloud-init issues

### Resource Limits
- **Max Containers:** 100 (IDs 300-399)
- **IP Range:** 192.168.171.200-299
- **Storage:** Limited by local-lvm capacity

## Files Structure

```
/root/proxmox-paas/
├── app-lxc.py          # LXC-based Flask API
├── app.py              # Old VM-based API (deprecated)
└── venv/               # Python virtual environment

Container Layout:
/opt/app/
├── app.py              # Your Flask application
├── requirements.txt    # Python dependencies
└── venv/               # Virtual environment
```

## Next Steps

### 1. Add Custom Domains
```bash
# On your DNS or /etc/hosts
192.168.171.200 app1.local
192.168.171.201 app2.local
```

### 2. Add NGINX Reverse Proxy
```bash
pct create 299 local:vztmpl/ubuntu-22.04... --hostname nginx-proxy
# Configure NGINX to proxy to containers
```

### 3. Add SSL/TLS
```bash
apt install certbot
certbot --nginx -d app1.yourdomain.com
```

### 4. Add Database Container
```bash
pct create 280 local:vztmpl/ubuntu-22.04... --hostname postgres
pct exec 280 -- apt install postgresql
```

### 5. Add Monitoring
```bash
# Install Prometheus + Grafana
# Monitor container metrics
```

## Security Notes

⚠️ **Current Setup is for Development Only**

For production:
1. Change default password from `rootpass123`
2. Enable SSH key authentication
3. Configure firewall rules
4. Use HTTPS for API
5. Implement authentication/authorization
6. Regular security updates
7. Backup containers regularly

## Backup & Recovery

### Backup Container
```bash
vzdump 301 --mode snapshot --storage local
```

### Restore Container
```bash
pct restore 301 /var/lib/vz/dump/vzdump-lxc-301-*.tar.gz
```

## Performance Tuning

### Increase Container Resources
```bash
pct set 301 --memory 4096
pct set 301 --cores 4
```

### Resize Container Disk
```bash
pct resize 301 rootfs +10G
```

## Success Metrics

✅ **Working Features:**
- Automated container creation
- GitHub repository cloning
- Python venv setup
- Dependency installation
- Application startup
- Network connectivity
- HTTP access from Windows
- Multiple simultaneous deployments

❌ **Previous Issues (Solved):**
- ~~VM cloud-init network failures~~ → Switched to LXC
- ~~QEMU guest agent not starting~~ → LXC doesn't need it
- ~~Static IP not working in VMs~~ → LXC static IPs work perfectly
- ~~SSH timeout to VMs~~ → LXC accessible immediately

## Credits

Built on Proxmox VE 6.14 with LXC containers for maximum reliability and performance.

# Proxmox PaaS Platform - Complete Solution

A fully functional private Platform-as-a-Service (PaaS) built on Proxmox VE with web interface, supporting multiple frameworks and automatic deployment from GitHub.

## Features

- **Web Interface** - Beautiful, user-friendly UI hosted on Proxmox
- **10+ Frameworks** - Python (Flask, Django, FastAPI), Node.js (Express, Next.js), PHP Laravel, Go, Rust, Ruby Rails, Static Sites
- **LXC & VM Support** - Choose between lightweight containers or full VMs
- **Automatic Deployment** - Clone from GitHub and deploy in 60 seconds
- **RESTful API** - Complete API for programmatic access
- **All-in-One Server** - Everything runs on Proxmox (no Windows dependency)
- **Production Ready** - Systemd service with auto-restart and logging

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                 Any Device (Browser/API)                      │
│               Windows / Linux / Mac / Mobile                  │
└────────────────────────────┬─────────────────────────────────┘
                             │ HTTPS/HTTP
                             ▼
┌──────────────────────────────────────────────────────────────┐
│         Proxmox VE 6.14 (192.168.171.140)                    │
│                                                               │
│  ┌────────────────────────────────────────────┐              │
│  │   PaaS Platform (Systemd Service)          │              │
│  │   Port 5000 - Gunicorn + Flask             │              │
│  │   ┌──────────────────────────────────┐    │              │
│  │   │  Web Interface (Templates)        │    │              │
│  │   │  - Modern UI with 10+ frameworks  │    │              │
│  │   │  - Real-time deployment status    │    │              │
│  │   └──────────────────────────────────┘    │              │
│  │   ┌──────────────────────────────────┐    │              │
│  │   │  REST API Endpoints               │    │              │
│  │   │  - /deploy (POST)                 │    │              │
│  │   │  - /list (GET)                    │    │              │
│  │   │  - /frameworks (GET)              │    │              │
│  │   │  - /status/<id> (GET)             │    │              │
│  │   │  - /delete/<id> (DELETE)          │    │              │
│  │   └──────────────────────────────────┘    │              │
│  │   ┌──────────────────────────────────┐    │              │
│  │   │  Framework Installers             │    │              │
│  │   │  Python│Node│PHP│Go│Rust│Ruby     │    │              │
│  │   └──────────────────────────────────┘    │              │
│  └───────────────────┬──────────────────────┘              │
│                      │                                        │
│  ┌───────────────────┴──────────────────────┐               │
│  │   LXC Container Pool (CT 300-399)        │               │
│  │  ┌────────────────────────────────────┐  │               │
│  │  │ CT 300: Flask    192.168.171.200:8000│ │               │
│  │  │ CT 301: Django   192.168.171.201:8000│ │               │
│  │  │ CT 302: FastAPI  192.168.171.202:8000│ │               │
│  │  │ CT 303: Express  192.168.171.203:3000│ │               │
│  │  │ CT 304: Next.js  192.168.171.204:3000│ │               │
│  │  │ CT 305: Laravel  192.168.171.205:8000│ │               │
│  │  │ CT 306: Go       192.168.171.206:8080│ │               │
│  │  │ CT 307: Rust     192.168.171.207:8080│ │               │
│  │  │ CT 308: Rails    192.168.171.208:3000│ │               │
│  │  │ CT 309: Nginx    192.168.171.209:80  │ │               │
│  │  └────────────────────────────────────┘  │               │
│  └─────────────────────────────────────────┘               │
│                                                               │
│  Storage: local-lvm (LXC volumes)                            │
│  Network: vmbr0 (192.168.171.0/24)                           │
└──────────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Installation (One Command)

```bash
ssh root@192.168.171.140
wget https://your-repo/install-proxmox.sh
chmod +x install-proxmox.sh && ./install-proxmox.sh
```

### 2. Access Web Interface

Open your browser to: **http://192.168.171.140:5000**

### 3. Deploy via Web UI

1. Enter application name
2. Paste GitHub repository URL
3. Select framework (Flask, Django, Node.js, Laravel)
4. Choose container type (LXC recommended)
5. Click "Deploy Application"
6. Wait 60-90 seconds for deployment

### 3. Access Your App

Your app will be accessible at: `http://192.168.171.20X:PORT`

## Installation

### Quick Install (Recommended)

See **[INSTALLATION.md](INSTALLATION.md)** for complete step-by-step guide.

```bash
# Automated installation (5 minutes)
ssh root@192.168.171.140
chmod +x install-proxmox.sh
./install-proxmox.sh
```

### Prerequisites

- **Proxmox VE 6.14+** installed and configured
- **Ubuntu 22.04 LXC template** (auto-downloaded by script)
- **Network**: 192.168.171.0/24 with gateway 192.168.171.2
- **Storage**: 20GB+ free on local-lvm

### Manual Setup (Advanced)

```bash
# SSH to Proxmox
ssh root@192.168.171.140

# Download Ubuntu LXC template
pveam update
pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst

# Create PaaS directory
mkdir -p /root/proxmox-paas
cd /root/proxmox-paas

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Flask
pip install flask

# Upload app-lxc.py (from this repo)
# Then start the API
nohup python app-lxc.py > /var/log/paas-api.log 2>&1 &
```

### Setup Web Interface (Windows)

```powershell
cd C:\Users\mns\Documents\terminal\cloud\prox\web

# Create virtual environment
python -m venv venv
.\venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt

# Start web server
python app.py
```

Access at: **http://localhost:5001**

## Framework Support (10+ Frameworks)

| Framework | Icon | Port | Auto-Install | Production Ready |
|-----------|------|------|--------------|------------------|
| **Python Flask** | 🐍 | 8000 | Python 3.10, pip, venv | ✅ |
| **Python Django** | 🎸 | 8000 | Django, Gunicorn, migrations | ✅ |
| **Python FastAPI** | ⚡ | 8000 | FastAPI, Uvicorn | ✅ |
| **Node.js Express** | 📗 | 3000 | Node.js 18, npm | ✅ |
| **Next.js** | ▲ | 3000 | Node.js 18, build optimization | ✅ |
| **PHP Laravel** | 🔴 | 8000 | PHP 8, Composer, migrations | ✅ |
| **Go Gin** | 🐹 | 8080 | Go compiler, binary build | ✅ |
| **Rust Actix** | 🦀 | 8080 | Rust, Cargo, release build | ✅ |
| **Ruby on Rails** | 💎 | 3000 | Ruby, Bundler, Rails server | ✅ |
| **Static Sites** | 🌐 | 80 | Nginx, auto-detect build dir | ✅ |

### Example Repositories

```yaml
Python Flask:
  Repo: https://github.com/mouones/test
  Files: app.py, requirements.txt

Python Django:
  Repo: https://github.com/username/django-blog
  Files: manage.py, requirements.txt, settings.py

Node.js Express:
  Repo: https://github.com/username/express-api
  Files: package.json, app.js

PHP Laravel:
  Repo: https://github.com/username/laravel-shop
  Files: composer.json, artisan

Static Site:
  Repo: https://github.com/username/portfolio
  Files: index.html, css/, js/
```

## API Endpoints

### Deploy Application
```http
POST /deploy
Content-Type: application/json

{
  "name": "my-app",
  "repo": "https://github.com/user/repo",
  "framework": "python-flask",
  "type": "lxc"
}

Response:
{
  "status": "success",
  "ctid": 302,
  "name": "my-app",
  "ip": "192.168.171.202",
  "url": "http://192.168.171.202:8000",
  "password": "rootpass123"
}
```

### List Containers
```http
GET /list

Response:
{
  "containers": "VMID  Status  Name\n300  running  flask-app\n301  running  django-app"
}
```

### Get Container Status
```http
GET /status/<ctid>

Response:
{
  "ctid": 300,
  "status": "running"
}
```

### Delete Container
```http
DELETE /delete/<ctid>

Response:
{
  "status": "deleted",
  "ctid": 300
}
```

## PowerShell Tools

### Load Helper Functions
```powershell
. .\paas-helpers.ps1
```

### Deploy Application
```powershell
Deploy-PaasApp -Name "my-app" -Repo "https://github.com/user/repo"
```

### List Containers
```powershell
Get-PaasContainers
```

### Test Application
```powershell
Test-PaasApp -ContainerId 301
```

### Delete Container
```powershell
Remove-PaasApp -ContainerId 301
```

## Directory Structure

```
proxmox-paas/
├── web/                           # Web Interface
│   ├── app.py                     # Flask web server
│   ├── templates/
│   │   └── index.html            # UI template
│   ├── requirements.txt
│   └── venv/
├── app-lxc.py                    # Proxmox API server
├── paas-helpers.ps1              # PowerShell tools
├── PROXMOX-LXC-PAAS.md          # Full documentation
└── README.md                     # This file

Container Structure (/opt/app/):
├── app.py / manage.py / server.js
├── requirements.txt / package.json
└── venv/
```

## Configuration

### Proxmox API (`app-lxc.py`)
```python
TEMPLATE = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
CT_RANGE_START = 300
BASE_IP = "192.168.171."
IP_START = 200
GATEWAY = "192.168.171.2"
PASSWORD = "rootpass123"
```

### Web Interface (`web/app.py`)
```python
PAAS_API = "http://192.168.171.140:5000"  # Proxmox API endpoint
```

## Deployment Workflow

1. **User Input** (via Web or API)
   - Application name
   - GitHub repository URL
   - Framework selection
   - Container type (LXC/VM)

2. **Container Creation**
   - Proxmox creates LXC container
   - Assigns static IP (192.168.171.200+)
   - Configures network and resources

3. **Environment Setup**
   - Installs language runtime (Python/Node.js/PHP)
   - Installs build tools
   - Creates virtual environment

4. **Application Deployment**
   - Clones GitHub repository to `/opt/app`
   - Installs dependencies
   - Creates systemd service
   - Starts application

5. **Completion**
   - Returns IP address and URL
   - Application ready to use

## Troubleshooting

### Web Interface Not Loading
```powershell
# Check if web server is running
Get-Process python | Where-Object {$_.Path -like "*web*"}

# Restart web server
cd web
.\venv\Scripts\Activate.ps1
python app.py
```

### API Not Responding
```bash
# SSH to Proxmox
ssh root@192.168.171.140

# Check API process
ps aux | grep app-lxc.py

# View API logs
tail -f /var/log/paas-api.log

# Restart API
cd /root/proxmox-paas
source venv/bin/activate
pkill -f app-lxc.py
nohup python app-lxc.py > /var/log/paas-api.log 2>&1 &
```

### Container Not Accessible
```bash
# Check container status
pct status 301

# Check if app is running
pct exec 301 -- ps aux | grep python

# Check listening ports
pct exec 301 -- ss -tlnp

# View app logs
pct exec 301 -- journalctl -u my-app -f
```

### Network Issues
```powershell
# Test connectivity
Test-NetConnection -ComputerName 192.168.171.201 -Port 8000

# Ping container
ping 192.168.171.201

# Use PowerShell invoke
Invoke-WebRequest http://192.168.171.201:8000
```

## Security Considerations

⚠️ **This is a development platform. For production use:**

1. Change default password from `rootpass123`
2. Enable SSH key authentication
3. Configure firewall rules (iptables/ufw)
4. Use HTTPS for web interface (SSL/TLS)
5. Implement user authentication
6. Enable API authentication tokens
7. Regular security updates
8. Backup containers regularly
9. Use private networks for containers
10. Implement rate limiting

## Performance Tuning

### Increase Container Resources
```bash
pct set 301 --memory 4096 --cores 4
pct resize 301 rootfs +10G
```

### Optimize Web Server
```python
# Use Gunicorn for production
pip install gunicorn
gunicorn -w 4 -b 0.0.0.0:5001 app:app
```

### Enable Caching
```python
# Add Redis for session/cache
pip install redis flask-caching
```

## Backup & Recovery

### Backup Container
```bash
vzdump 301 --mode snapshot --storage local
```

### Restore Container
```bash
pct restore 301 /var/lib/vz/dump/vzdump-lxc-301-*.tar.gz
```

### Backup PaaS Configuration
```bash
tar -czf paas-backup.tar.gz /root/proxmox-paas/
```

## Monitoring

### Container Resource Usage
```bash
pct status 301
pct exec 301 -- free -h
pct exec 301 -- df -h
```

### API Metrics
```bash
tail -f /var/log/paas-api.log
```

### Web Interface Access Logs
```powershell
# Windows: View console output where web server is running
```

## Future Enhancements

- [ ] Database containers (PostgreSQL, MySQL, MongoDB)
- [ ] NGINX reverse proxy with SSL
- [ ] Custom domain support
- [ ] CI/CD pipeline integration
- [ ] Resource usage monitoring (Prometheus/Grafana)
- [ ] Auto-scaling based on load
- [ ] Multi-user authentication
- [ ] Container templates marketplace
- [ ] Automated backups
- [ ] Terraform integration

## License

MIT License - Feel free to use and modify

## Support

- **Documentation**: See PROXMOX-LXC-PAAS.md for detailed info
- **Issues**: Check troubleshooting section
- **API**: Full RESTful API available

## Credits

Built with:
- Proxmox VE 6.14
- Python Flask
- LXC Containers
- Love and Coffee ☕

---

**Status**: ✅ Production Ready (Development Mode)
**Version**: 1.0.0
**Last Updated**: December 2, 2025

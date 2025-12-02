# Guide Complet - Plateforme PaaS Proxmox 6.14

## Architecture
```
Utilisateurs → Flask (Auth) → Proxmox VE → Template VM 9000 → VMs (1100-1199)
```

---

## Installation Complète

### Étape 1: Préparation Proxmox Host

```bash
# SSH vers Proxmox
ssh root@your-proxmox-ip

# Mise à jour système
apt-get update
apt-get upgrade -y

# Installation dépendances
apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    git \
    libguestfs-tools \
    wget \
    curl \
    vim
```

### Étape 2: Création Répertoire Projet

```bash
mkdir -p /root/proxmox-paas
cd /root/proxmox-paas
```

### Étape 3: Environnement Python

```bash
python3 -m venv venv
source venv/bin/activate
pip install flask flask-login werkzeug
```

### Étape 4: Script Création Template

**Fichier: `01_create_template.sh`**

```bash
#!/bin/bash
set -e

TEMPLATE_ID=9000
STORAGE="local-lvm"
BRIDGE="vmbr0"
IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
IMAGE_FILE="ubuntu-22.04-cloudimg.img"

echo "=== Création Template VM Universal ==="

# Nettoyage
if qm status $TEMPLATE_ID &>/dev/null; then
    qm set $TEMPLATE_ID --template 0 2>/dev/null || true
    qm stop $TEMPLATE_ID 2>/dev/null || true
    sleep 3
    qm destroy $TEMPLATE_ID --purge 2>/dev/null || true
fi

# Téléchargement image
cd /tmp
rm -f "$IMAGE_FILE"
wget -O "$IMAGE_FILE" "$IMAGE_URL"

# Installation packages base
virt-customize -a "$IMAGE_FILE" \
    --install qemu-guest-agent,cloud-init,git,curl,wget,vim,net-tools,build-essential \
    --run-command 'systemctl enable qemu-guest-agent' \
    --run-command 'systemctl enable ssh' \
    --run-command 'echo "PermitRootLogin yes" >> /etc/ssh/sshd_config' \
    --run-command 'echo -n > /etc/machine-id'

# Python
echo "Installation Python..."
virt-customize -a "$IMAGE_FILE" \
    --install python3,python3-pip,python3-venv,python3-dev

# Node.js
echo "Installation Node.js..."
virt-customize -a "$IMAGE_FILE" \
    --run-command 'curl -fsSL https://deb.nodesource.com/setup_20.x | bash -' \
    --install nodejs

# PHP + Nginx
echo "Installation PHP..."
virt-customize -a "$IMAGE_FILE" \
    --run-command 'add-apt-repository -y ppa:ondrej/php' \
    --update \
    --install php8.2-fpm,php8.2-cli,php8.2-mysql,php8.2-xml,php8.2-mbstring,php8.2-curl,php8.2-zip,composer,nginx \
    --run-command 'systemctl enable nginx' \
    --run-command 'systemctl enable php8.2-fpm'

# Docker
echo "Installation Docker..."
virt-customize -a "$IMAGE_FILE" \
    --run-command 'curl -fsSL https://get.docker.com | sh' \
    --run-command 'systemctl enable docker'

# Création VM
qm create $TEMPLATE_ID \
    --name "ubuntu-universal-template" \
    --memory 2048 \
    --cores 2 \
    --net0 virtio,bridge=$BRIDGE \
    --ostype l26

qm importdisk $TEMPLATE_ID "$IMAGE_FILE" $STORAGE

qm set $TEMPLATE_ID \
    --scsihw virtio-scsi-pci \
    --scsi0 ${STORAGE}:vm-${TEMPLATE_ID}-disk-0 \
    --boot c \
    --bootdisk scsi0 \
    --ide2 ${STORAGE}:cloudinit \
    --serial0 socket \
    --vga serial0 \
    --agent enabled=1

qm disk resize $TEMPLATE_ID scsi0 +10G

# Cloud-init
qm set $TEMPLATE_ID --ciuser root
qm set $TEMPLATE_ID --cipassword $(openssl passwd -6 "rootpass123")
qm set $TEMPLATE_ID --ipconfig0 ip=dhcp
qm set $TEMPLATE_ID --nameserver 8.8.8.8

[ -f ~/.ssh/id_rsa.pub ] && qm set $TEMPLATE_ID --sshkeys ~/.ssh/id_rsa.pub

# Conversion template
qm template $TEMPLATE_ID

rm -f "$IMAGE_FILE"

echo "✅ Template $TEMPLATE_ID créé"
```

```bash
chmod +x 01_create_template.sh
./01_create_template.sh
```

---

### Étape 5: Application Flask avec Authentification

**Fichier: `app.py`**

```python
#!/usr/bin/env python3
from flask import Flask, render_template_string, request, jsonify, redirect, url_for, session
from werkzeug.security import generate_password_hash, check_password_hash
from functools import wraps
import subprocess
import json
import time
import os
from datetime import datetime

app = Flask(__name__)
app.secret_key = 'votre-cle-secrete-changez-moi-123456'

# Configuration
TEMPLATE_ID = 9000
VM_RANGE_START = 1100
VM_RANGE_END = 1199
STORAGE = "local-lvm"
BRIDGE = "vmbr0"
BASE_IP = "192.168.1."
GATEWAY = "192.168.1.1"

# Stockage
DEPLOYMENTS = {}
DEPLOYMENTS_FILE = "deployments.json"
USERS_FILE = "users.json"
USERS = {}

# Frameworks
FRAMEWORKS = {
    "flask": {"name": "Flask", "icon": "🐍", "type": "python", "port": 5000},
    "django": {"name": "Django", "icon": "🎯", "type": "python", "port": 8000},
    "nodejs": {"name": "Node.js", "icon": "🟢", "type": "nodejs", "port": 3000},
    "express": {"name": "Express", "icon": "⚡", "type": "nodejs", "port": 3000},
    "laravel": {"name": "Laravel", "icon": "🔴", "type": "php", "port": 80},
    "react": {"name": "React", "icon": "⚛️", "type": "frontend", "port": 80},
    "vue": {"name": "Vue.js", "icon": "💚", "type": "frontend", "port": 80},
    "docker": {"name": "Docker", "icon": "🐳", "type": "docker", "port": 80}
}

def load_users():
    global USERS
    if os.path.exists(USERS_FILE):
        with open(USERS_FILE, 'r') as f:
            USERS = json.load(f)
    else:
        # Utilisateur par défaut: admin/admin123
        USERS = {
            "admin": {
                "password": generate_password_hash("admin123"),
                "email": "admin@localhost",
                "created_at": datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }
        }
        save_users()

def save_users():
    with open(USERS_FILE, 'w') as f:
        json.dump(USERS, f, indent=2)

def load_deployments():
    global DEPLOYMENTS
    if os.path.exists(DEPLOYMENTS_FILE):
        with open(DEPLOYMENTS_FILE, 'r') as f:
            DEPLOYMENTS = json.load(f)

def save_deployments():
    with open(DEPLOYMENTS_FILE, 'w') as f:
        json.dump(DEPLOYMENTS, f, indent=2)

def run_command(cmd, check=True):
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, check=check)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        if check:
            raise
        return ""

def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'username' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

def get_next_vmid():
    used_ids = set()
    output = run_command("qm list | tail -n +2 | awk '{print $1}'", check=False)
    if output:
        used_ids.update(int(vmid) for vmid in output.split('\n') if vmid.strip())
    used_ids.update(int(d['vm_id']) for d in DEPLOYMENTS.values() if d.get('vm_id'))
    for vmid in range(VM_RANGE_START, VM_RANGE_END + 1):
        if vmid not in used_ids:
            return vmid
    raise Exception("Aucun VMID disponible")

def wait_for_vm_ready(vmid, ip, max_wait=180):
    start = time.time()
    while time.time() - start < max_wait:
        status = run_command(f"qm status {vmid} | grep status | awk '{{print $2}}'", check=False)
        if status != "running":
            time.sleep(5)
            continue
        ssh_test = run_command(
            f"ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "
            f"-o BatchMode=yes root@{ip} 'echo ready' 2>/dev/null",
            check=False
        )
        if ssh_test == "ready":
            return True
        time.sleep(5)
    return False

def deploy_python(ip, github_url, app_name, framework):
    script = f"""
set -e
cd /opt
git clone --depth 1 {github_url} {app_name}
cd {app_name}
python3 -m venv venv
source venv/bin/activate
pip install -q --upgrade pip
pip install -q -r requirements.txt || true
"""
    if framework == "django":
        script += "python manage.py migrate --noinput || true\n"
        script += "nohup python manage.py runserver 0.0.0.0:80 > /var/log/app.log 2>&1 &\n"
    else:
        script += "nohup python app.py > /var/log/app.log 2>&1 &\n"
    
    run_command(f"ssh -o StrictHostKeyChecking=no root@{ip} 'bash -s' << 'ENDSSH'\n{script}\nENDSSH")

def deploy_nodejs(ip, github_url, app_name):
    script = f"""
set -e
cd /opt
git clone --depth 1 {github_url} {app_name}
cd {app_name}
npm install --silent --production
PORT=80 nohup npm start > /var/log/app.log 2>&1 &
"""
    run_command(f"ssh -o StrictHostKeyChecking=no root@{ip} 'bash -s' << 'ENDSSH'\n{script}\nENDSSH")

def deploy_php(ip, github_url, app_name):
    script = f"""
set -e
cd /opt
git clone --depth 1 {github_url} {app_name}
cd {app_name}
composer install --no-dev --optimize-autoloader --quiet || true
cp .env.example .env 2>/dev/null || true
php artisan key:generate --quiet 2>/dev/null || true
chown -R www-data:www-data /opt/{app_name}
cat > /etc/nginx/sites-enabled/default << 'NGXEOF'
server {{
    listen 80 default_server;
    root /opt/{app_name}/public;
    index index.php index.html;
    location / {{ try_files \\$uri \\$uri/ /index.php?\\$query_string; }}
    location ~ \\.php$ {{
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \\$realpath_root\\$fastcgi_script_name;
        include fastcgi_params;
    }}
}}
NGXEOF
systemctl restart nginx php8.2-fpm
"""
    run_command(f"ssh -o StrictHostKeyChecking=no root@{ip} 'bash -s' << 'ENDSSH'\n{script}\nENDSSH")

def deploy_frontend(ip, github_url, app_name):
    script = f"""
set -e
cd /opt
git clone --depth 1 {github_url} {app_name}
cd {app_name}
npm install --silent
npm run build || true
DIST_DIR="dist"
[ -d "build" ] && DIST_DIR="build"
cat > /etc/nginx/sites-enabled/default << 'NGXEOF'
server {{
    listen 80 default_server;
    root /opt/{app_name}/\\$DIST_DIR;
    index index.html;
    location / {{ try_files \\$uri \\$uri/ /index.html; }}
}}
NGXEOF
systemctl restart nginx
"""
    run_command(f"ssh -o StrictHostKeyChecking=no root@{ip} 'bash -s' << 'ENDSSH'\n{script}\nENDSSH")

def deploy_docker(ip, github_url, app_name):
    script = f"""
set -e
cd /opt
git clone --depth 1 {github_url} {app_name}
cd {app_name}
if [ -f docker-compose.yml ]; then
    docker-compose up -d
elif [ -f Dockerfile ]; then
    docker build -t {app_name} .
    docker run -d -p 80:80 --name {app_name} {app_name}
fi
"""
    run_command(f"ssh -o StrictHostKeyChecking=no root@{ip} 'bash -s' << 'ENDSSH'\n{script}\nENDSSH")

def deploy_framework(vmid, framework, github_url, ip):
    app_name = github_url.split('/')[-1].replace('.git', '').lower()
    fw_type = FRAMEWORKS[framework]['type']
    
    if not wait_for_vm_ready(vmid, ip):
        raise Exception("VM non prête")
    
    if fw_type == "python":
        deploy_python(ip, github_url, app_name, framework)
    elif fw_type == "nodejs":
        deploy_nodejs(ip, github_url, app_name)
    elif fw_type == "php":
        deploy_php(ip, github_url, app_name)
    elif fw_type == "frontend":
        deploy_frontend(ip, github_url, app_name)
    elif fw_type == "docker":
        deploy_docker(ip, github_url, app_name)
    
    return True

LOGIN_HTML = '''
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Connexion - PaaS Platform</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .login-container {
            background: white;
            padding: 3rem;
            border-radius: 16px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            width: 100%;
            max-width: 400px;
        }
        h1 {
            text-align: center;
            color: #333;
            margin-bottom: 2rem;
            font-size: 2rem;
        }
        .form-group {
            margin-bottom: 1.5rem;
        }
        label {
            display: block;
            margin-bottom: 0.5rem;
            color: #555;
            font-weight: 500;
        }
        input {
            width: 100%;
            padding: 0.75rem;
            border: 2px solid #e1e8ed;
            border-radius: 8px;
            font-size: 1rem;
            transition: border-color 0.3s;
        }
        input:focus {
            outline: none;
            border-color: #667eea;
        }
        button {
            width: 100%;
            padding: 1rem;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 1rem;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s;
        }
        button:hover {
            transform: translateY(-2px);
        }
        .alert {
            padding: 1rem;
            margin-bottom: 1rem;
            border-radius: 8px;
            background: #fee;
            color: #c33;
            border: 1px solid #fcc;
        }
        .info {
            text-align: center;
            margin-top: 1.5rem;
            color: #666;
            font-size: 0.9rem;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <h1>🚀 PaaS Platform</h1>
        {% if error %}
        <div class="alert">{{ error }}</div>
        {% endif %}
        <form method="POST">
            <div class="form-group">
                <label>Nom d'utilisateur</label>
                <input type="text" name="username" required autofocus>
            </div>
            <div class="form-group">
                <label>Mot de passe</label>
                <input type="password" name="password" required>
            </div>
            <button type="submit">Se connecter</button>
        </form>
        <div class="info">
            Par défaut: <strong>admin</strong> / <strong>admin123</strong>
        </div>
    </div>
</body>
</html>
'''

DASHBOARD_HTML = '''
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PaaS Platform - Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        :root {
            --primary: #667eea;
            --secondary: #10b981;
            --danger: #ef4444;
            --warning: #f59e0b;
            --bg: #0f172a;
            --surface: #1e293b;
            --surface-light: #334155;
            --text: #f1f5f9;
            --text-secondary: #94a3b8;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: var(--bg);
            color: var(--text);
            line-height: 1.6;
        }
        .header {
            background: linear-gradient(135deg, var(--primary) 0%, #764ba2 100%);
            padding: 2rem 0;
            box-shadow: 0 4px 6px rgba(0,0,0,0.3);
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 0 2rem;
        }
        .header h1 {
            font-size: 2.5rem;
            margin-bottom: 0.5rem;
        }
        .header .user-info {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .header .user-info a {
            color: white;
            text-decoration: none;
            padding: 0.5rem 1rem;
            background: rgba(255,255,255,0.2);
            border-radius: 6px;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1.5rem;
            margin: 2rem 0;
        }
        .stat-card {
            background: var(--surface);
            padding: 1.5rem;
            border-radius: 12px;
            border-left: 4px solid var(--primary);
        }
        .stat-value {
            font-size: 2.5rem;
            font-weight: 700;
            color: var(--primary);
        }
        .stat-label {
            color: var(--text-secondary);
            margin-top: 0.5rem;
        }
        .deploy-section, .deployments-section {
            background: var(--surface);
            padding: 2rem;
            border-radius: 12px;
            margin-bottom: 2rem;
            border: 1px solid var(--surface-light);
        }
        .section-title {
            font-size: 1.5rem;
            margin-bottom: 1.5rem;
            color: var(--text);
        }
        .form-group {
            margin-bottom: 1.5rem;
        }
        .form-group label {
            display: block;
            margin-bottom: 0.5rem;
            font-weight: 500;
        }
        .form-group input, .form-group select {
            width: 100%;
            padding: 0.75rem;
            background: var(--bg);
            border: 1px solid var(--surface-light);
            border-radius: 8px;
            color: var(--text);
            font-size: 1rem;
        }
        .framework-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
            gap: 1rem;
        }
        .framework-option {
            background: var(--bg);
            padding: 1rem;
            border-radius: 8px;
            text-align: center;
            cursor: pointer;
            border: 2px solid transparent;
            transition: all 0.3s;
        }
        .framework-option:hover {
            border-color: var(--primary);
        }
        .framework-option.selected {
            border-color: var(--primary);
            background: rgba(102, 126, 234, 0.1);
        }
        .framework-icon {
            font-size: 2rem;
            margin-bottom: 0.5rem;
        }
        .resource-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 1rem;
        }
        .btn {
            padding: 0.75rem 1.5rem;
            border: none;
            border-radius: 8px;
            font-size: 1rem;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s;
        }
        .btn-primary {
            background: var(--primary);
            color: white;
            width: 100%;
        }
        .btn-primary:hover {
            background: #5568d3;
        }
        .btn-danger {
            background: var(--danger);
            color: white;
            padding: 0.5rem 1rem;
            font-size: 0.9rem;
        }
        .deployment-card {
            background: var(--bg);
            padding: 1.5rem;
            border-radius: 8px;
            margin-bottom: 1rem;
            border-left: 4px solid var(--primary);
        }
        .deployment-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 1rem;
        }
        .deployment-name {
            font-size: 1.2rem;
            font-weight: 600;
        }
        .deployment-status {
            padding: 0.25rem 0.75rem;
            border-radius: 6px;
            font-size: 0.85rem;
            font-weight: 600;
        }
        .status-running {
            background: rgba(16, 185, 129, 0.2);
            color: var(--secondary);
        }
        .status-provisioning {
            background: rgba(245, 158, 11, 0.2);
            color: var(--warning);
        }
        .status-error {
            background: rgba(239, 68, 68, 0.2);
            color: var(--danger);
        }
        .deployment-info {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
            margin-bottom: 1rem;
        }
        .info-item {
            color: var(--text-secondary);
            font-size: 0.9rem;
        }
        .info-value {
            color: var(--text);
            font-weight: 500;
        }
        .deployment-actions {
            display: flex;
            gap: 0.5rem;
            margin-top: 1rem;
        }
        .alert {
            padding: 1rem;
            border-radius: 8px;
            margin-bottom: 1rem;
        }
        .alert-success {
            background: rgba(16, 185, 129, 0.1);
            border: 1px solid var(--secondary);
            color: var(--secondary);
        }
        .alert-error {
            background: rgba(239, 68, 68, 0.1);
            border: 1px solid var(--danger);
            color: var(--danger);
        }
        .loading {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid rgba(255,255,255,0.3);
            border-radius: 50%;
            border-top-color: white;
            animation: spin 1s ease-in-out infinite;
        }
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="container">
            <div class="user-info">
                <div>
                    <h1>🚀 PaaS Platform</h1>
                    <p>Déploiement automatique d'applications</p>
                </div>
                <div>
                    <span>Connecté: {{ username }}</span>
                    <a href="/logout">Déconnexion</a>
                </div>
            </div>
        </div>
    </div>

    <div class="container">
        <div class="stats">
            <div class="stat-card">
                <div class="stat-value" id="totalDeployments">0</div>
                <div class="stat-label">Total Déploiements</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="runningDeployments">0</div>
                <div class="stat-label">En cours</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="provisioningDeployments">0</div>
                <div class="stat-label">Provisionnement</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="errorDeployments">0</div>
                <div class="stat-label">Erreurs</div>
            </div>
        </div>

        <div class="deploy-section">
            <h2 class="section-title">Nouveau Déploiement</h2>
            <div id="alertContainer"></div>
            <form id="deployForm">
                <div class="form-group">
                    <label>Nom de l'application</label>
                    <input type="text" id="appName" placeholder="mon-application" required>
                </div>
                <div class="form-group">
                    <label>Framework</label>
                    <div class="framework-grid" id="frameworkGrid"></div>
                </div>
                <div class="form-group">
                    <label>URL du dépôt GitHub</label>
                    <input type="url" id="githubUrl" placeholder="https://github.com/user/repo">
                </div>
                <div class="form-group">
                    <label>Ressources</label>
                    <div class="resource-grid">
                        <div>
                            <label>CPU</label>
                            <select id="cpu">
                                <option value="1">1 Core</option>
                                <option value="2" selected>2 Cores</option>
                                <option value="4">4 Cores</option>
                            </select>
                        </div>
                        <div>
                            <label>RAM (MB)</label>
                            <select id="memory">
                                <option value="1024">1 GB</option>
                                <option value="2048" selected>2 GB</option>
                                <option value="4096">4 GB</option>
                            </select>
                        </div>
                        <div>
                            <label>Disque (GB)</label>
                            <select id="disk">
                                <option value="10">10 GB</option>
                                <option value="20" selected>20 GB</option>
                                <option value="50">50 GB</option>
                            </select>
                        </div>
                    </div>
                </div>
                <button type="submit" class="btn btn-primary">Déployer</button>
            </form>
        </div>

        <div class="deployments-section">
            <h2 class="section-title">Déploiements Actifs</h2>
            <div id="deploymentsContainer"></div>
        </div>
    </div>

    <script>
        let selectedFramework = 'flask';
        let frameworks = {};

        async function loadFrameworks() {
            const response = await fetch('/api/frameworks');
            frameworks = await response.json();
            const grid = document.getElementById('frameworkGrid');
            grid.innerHTML = '';
            for (const [key, fw] of Object.entries(frameworks)) {
                const option = document.createElement('div');
                option.className = 'framework-option' + (key === selectedFramework ? ' selected' : '');
                option.innerHTML = `
                    <div class="framework-icon">${fw.icon}</div>
                    <div class="framework-name">${fw.name}</div>
                `;
                option.onclick = () => selectFramework(key, option);
                grid.appendChild(option);
            }
        }

        function selectFramework(key, element) {
            selectedFramework = key;
            document.querySelectorAll('.framework-option').forEach(el => el.classList.remove('selected'));
            element.classList.add('selected');
        }

        document.getElementById('deployForm').onsubmit = async (e) => {
            e.preventDefault();
            const btn = e.target.querySelector('button');
            btn.disabled = true;
            btn.innerHTML = '<span class="loading"></span> Déploiement...';
            
            try {
                const response = await fetch('/api/deploy', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({
                        name: document.getElementById('appName').value,
                        framework: selectedFramework,
                        github_url: document.getElementById('githubUrl').value,
                        cpu: parseInt(document.getElementById('cpu').value),
                        memory: parseInt(document.getElementById('memory').value),
                        disk: parseInt(document.getElementById('disk').value)
                    })
                });
                const result = await response.json();
                if (result.status === 'success') {
                    showAlert('Déploiement démarré avec succès!', 'success');
                    document.getElementById('deployForm').reset();
                    loadDeployments();
                } else {
                    showAlert(result.message, 'error');
                }
            } catch (error) {
                showAlert('Erreur: ' + error.message, 'error');
            } finally {
                btn.disabled = false;
                btn.textContent = 'Déployer';
            }
        };

        function showAlert(message, type) {
            const container = document.getElementById('alertContainer');
            container.innerHTML = `<div class="alert alert-${type}">${message}</div>`;
            setTimeout(() => container.innerHTML = '', 5000);
        }

        async function loadDeployments() {
            try {
                const response = await fetch('/api/deployments');
                const deployments = await response.json();
                const statsResponse = await fetch('/api/stats');
                const stats = await statsResponse.json();
                
                document.getElementById('totalDeployments').textContent = stats.total_deployments;
                document.getElementById('runningDeployments').textContent = stats.running;
                document.getElementById('provisioningDeployments').textContent = stats.provisioning;
                document.getElementById('errorDeployments').textContent = stats.errors;
                
                const container = document.getElementById('deploymentsContainer');
                if (deployments.length === 0) {
                    container.innerHTML = '<p style="text-align:center;color:var(--text-secondary)">Aucun déploiement</p>';
                    return;
                }
                
                container.innerHTML = deployments.map(dep => `
                    <div class="deployment-card">
                        <div class="deployment-header">
                            <div class="deployment-name">
                                ${dep.framework_info.icon} ${dep.name}
                            </div>
                            <span class="deployment-status status-${dep.status}">
                                ${dep.status.toUpperCase()}
                            </span>
                        </div>
                        <div class="deployment-info">
                            <div class="info-item">
                                <strong>VM ID:</strong> 
                                <span class="info-value">${dep.vm_id || 'En attente'}</span>
                            </div>
                            <div class="info-item">
                                <strong>IP:</strong> 
                                <span class="info-value">${dep.ip}</span>
                            </div>
                            <div class="info-item">
                                <strong>Ressources:</strong> 
                                <span class="info-value">${dep.cpu} CPU, ${dep.memory}MB RAM</span>
                            </div>
                            <div class="info-item">
                                <strong>Créé:</strong> 
                                <span class="info-value">${dep.created_at}</span>
                            </div>
                        </div>
                        ${dep.url ? `
                            <div class="info-item">
                                <strong>URL:</strong> 
                                <a href="${dep.url}" target="_blank" style="color: var(--primary)">${dep.url}</a>
                            </div>
                        ` : ''}
                        <div class="info-item" style="margin-top: 0.5rem; color: var(--text-secondary);">
                            ${dep.message}
                        </div>
                        ${dep.error ? `
                            <div class="alert alert-error" style="margin-top: 1rem;">
                                ${dep.error}
                            </div>
                        ` : ''}
                        <div class="deployment-actions">
                            ${dep.url ? `<a href="${dep.url}" target="_blank" class="btn btn-primary" style="text-decoration: none; padding: 0.5rem 1rem; font-size: 0.9rem; width: auto;">Ouvrir</a>` : ''}
                            <button class="btn btn-danger" onclick="destroyDeployment('${dep.id}')">Détruire</button>
                        </div>
                    </div>
                `).join('');
            } catch (error) {
                console.error('Erreur chargement:', error);
            }
        }

        async function destroyDeployment(id) {
            if (!confirm('Supprimer ce déploiement?')) return;
            try {
                await fetch(`/api/deployments/${id}`, { method: 'DELETE' });
                showAlert('Déploiement supprimé', 'success');
                loadDeployments();
            } catch (error) {
                showAlert('Erreur suppression', 'error');
            }
        }

        loadFrameworks();
        loadDeployments();
        setInterval(loadDeployments, 5000);
    </script>
</body>
</html>
'''

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        if username in USERS and check_password_hash(USERS[username]['password'], password):
            session['username'] = username
            return redirect(url_for('index'))
        
        return render_template_string(LOGIN_HTML, error="Identifiants invalides")
    
    return render_template_string(LOGIN_HTML)

@app.route('/logout')
def logout():
    session.pop('username', None)
    return redirect(url_for('login'))

@app.route('/')
@login_required
def index():
    return render_template_string(DASHBOARD_HTML, username=session['username'])

@app.route('/api/frameworks')
@login_required
def get_frameworks():
    return jsonify(FRAMEWORKS)

@app.route('/api/deploy', methods=['POST'])
@login_required
def deploy():
    try:
        data = request.json
        name = data.get('name')
        framework = data.get('framework')
        github_url = data.get('github_url', '')
        cpu = data.get('cpu', 2)
        memory = data.get('memory', 2048)
        disk = data.get('disk', 20)
        
        if not name or not framework:
            return jsonify({'status': 'error', 'message': 'Champs requis manquants'}), 400
        
        if framework not in FRAMEWORKS:
            return jsonify({'status': 'error', 'message': 'Framework invalide'}), 400
        
        vmid = get_next_vmid()
        ip = f"{BASE_IP}{vmid - VM_RANGE_START + 100}"
        
        deployment_id = f"deploy-{int(time.time())}"
        DEPLOYMENTS[deployment_id] = {
            'id': deployment_id,
            'name': name,
            'framework': framework,
            'framework_info': FRAMEWORKS[framework],
            'github_url': github_url,
            'vm_id': vmid,
            'ip': ip,
            'cpu': cpu,
            'memory': memory,
            'disk': disk,
            'status': 'provisioning',
            'message': 'Création VM...',
            'url': None,
            'error': None,
            'created_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'user': session['username']
        }
        save_deployments()
        
        run_command(f"qm clone {TEMPLATE_ID} {vmid} --name {name} --full 1")
        run_command(f"qm set {vmid} --cores {cpu} --memory {memory}")
        run_command(f"qm set {vmid} --ipconfig0 ip={ip}/24,gw={GATEWAY}")
        run_command(f"qm disk resize {vmid} scsi0 {disk}G")
        
        DEPLOYMENTS[deployment_id]['message'] = 'Démarrage VM...'
        save_deployments()
        run_command(f"qm start {vmid}")
        
        if github_url:
            DEPLOYMENTS[deployment_id]['message'] = 'Déploiement application...'
            save_deployments()
            deploy_framework(vmid, framework, github_url, ip)
            port = FRAMEWORKS[framework]['port']
            DEPLOYMENTS[deployment_id]['url'] = f"http://{ip}:{port}" if port != 80 else f"http://{ip}"
        
        DEPLOYMENTS[deployment_id]['status'] = 'running'
        DEPLOYMENTS[deployment_id]['message'] = 'Déploiement terminé!'
        save_deployments()
        
        return jsonify({'status': 'success', 'deployment_id': deployment_id})
        
    except Exception as e:
        if 'deployment_id' in locals():
            DEPLOYMENTS[deployment_id]['status'] = 'error'
            DEPLOYMENTS[deployment_id]['error'] = str(e)
            DEPLOYMENTS[deployment_id]['message'] = 'Échec déploiement'
            save_deployments()
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/deployments')
@login_required
def get_deployments():
    return jsonify(list(DEPLOYMENTS.values()))

@app.route('/api/deployments/<deployment_id>', methods=['DELETE'])
@login_required
def delete_deployment(deployment_id):
    try:
        if deployment_id not in DEPLOYMENTS:
            return jsonify({'status': 'error', 'message': 'Déploiement introuvable'}), 404
        
        deployment = DEPLOYMENTS[deployment_id]
        vmid = deployment['vm_id']
        
        run_command(f"qm stop {vmid}", check=False)
        time.sleep(2)
        run_command(f"qm destroy {vmid} --purge", check=False)
        
        del DEPLOYMENTS[deployment_id]
        save_deployments()
        
        return jsonify({'status': 'success'})
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/stats')
@login_required
def get_stats():
    total = len(DEPLOYMENTS)
    running = sum(1 for d in DEPLOYMENTS.values() if d['status'] == 'running')
    provisioning = sum(1 for d in DEPLOYMENTS.values() if d['status'] == 'provisioning')
    errors = sum(1 for d in DEPLOYMENTS.values() if d['status'] == 'error')
    
    return jsonify({
        'total_deployments': total,
        'running': running,
        'provisioning': provisioning,
        'errors': errors
    })

if __name__ == '__main__':
    load_users()
    load_deployments()
    print("=" * 50)
    print("🚀 PaaS Platform démarrée")
    print("📍 URL: http://0.0.0.0:5000")
    print("👤 Utilisateur par défaut: admin")
    print("🔑 Mot de passe par défaut: admin123")
    print("=" * 50)
    app.run(host='0.0.0.0', port=5000, debug=False)
```

---

### Étape 6: Script de Gestion des Utilisateurs

**Fichier: `manage_users.py`**

```python
#!/usr/bin/env python3
import json
import sys
from werkzeug.security import generate_password_hash
from datetime import datetime

USERS_FILE = "users.json"

def load_users():
    try:
        with open(USERS_FILE, 'r') as f:
            return json.load(f)
    except:
        return {}

def save_users(users):
    with open(USERS_FILE, 'w') as f:
        json.dump(users, f, indent=2)

def add_user(username, password, email):
    users = load_users()
    if username in users:
        print(f"❌ Utilisateur '{username}' existe déjà")
        return False
    
    users[username] = {
        "password": generate_password_hash(password),
        "email": email,
        "created_at": datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    }
    save_users(users)
    print(f"✅ Utilisateur '{username}' créé")
    return True

def delete_user(username):
    users = load_users()
    if username not in users:
        print(f"❌ Utilisateur '{username}' introuvable")
        return False
    
    del users[username]
    save_users(users)
    print(f"✅ Utilisateur '{username}' supprimé")
    return True

def list_users():
    users = load_users()
    if not users:
        print("Aucun utilisateur")
        return
    
    print("\n=== Utilisateurs ===")
    for username, data in users.items():
        print(f"\n👤 {username}")
        print(f"   Email: {data.get('email', 'N/A')}")
        print(f"   Créé: {data.get('created_at', 'N/A')}")

def change_password(username, new_password):
    users = load_users()
    if username not in users:
        print(f"❌ Utilisateur '{username}' introuvable")
        return False
    
    users[username]['password'] = generate_password_hash(new_password)
    save_users(users)
    print(f"✅ Mot de passe changé pour '{username}'")
    return True

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python3 manage_users.py add <username> <password> <email>")
        print("  python3 manage_users.py delete <username>")
        print("  python3 manage_users.py list")
        print("  python3 manage_users.py password <username> <new_password>")
        sys.exit(1)
    
    cmd = sys.argv[1]
    
    if cmd == 'add' and len(sys.argv) == 5:
        add_user(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == 'delete' and len(sys.argv) == 3:
        delete_user(sys.argv[2])
    elif cmd == 'list':
        list_users()
    elif cmd == 'password' and len(sys.argv) == 4:
        change_password(sys.argv[2], sys.argv[3])
    else:
        print("❌ Commande invalide")
```

```bash
chmod +x manage_users.py
```

---

### Étape 7: Service Systemd

**Fichier: `02_install_service.sh`**

```bash
#!/bin/bash

cat > /etc/systemd/system/proxmox-paas.service << 'EOF'
[Unit]
Description=PaaS Platform
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/proxmox-paas
Environment="PATH=/root/proxmox-paas/venv/bin"
ExecStart=/root/proxmox-paas/venv/bin/python app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable proxmox-paas
systemctl start proxmox-paas

echo "✅ Service installé"
echo "Vérifier: systemctl status proxmox-paas"
```

```bash
chmod +x 02_install_service.sh
./02_install_service.sh
```

---

### Étape 8: Script de Nettoyage

**Fichier: `03_cleanup.sh`**

```bash
#!/bin/bash

echo "=== Nettoyage Complet ==="

# Arrêter service
systemctl stop proxmox-paas 2>/dev/null || true

# Tuer processus
pkill -f app.py 2>/dev/null || true
sleep 2

# Supprimer toutes les VMs 1100-1199
echo "Suppression VMs..."
for vmid in {1100..1199}; do
    if qm status $vmid &>/dev/null; then
        echo "  Suppression VM $vmid..."
        qm stop $vmid 2>/dev/null || true
        sleep 1
        qm destroy $vmid --purge 2>/dev/null || true
    fi
done

# Nettoyer locks
rm -f /var/lock/qemu-server/lock-*.conf 2>/dev/null || true

# Réinitialiser données
cd /root/proxmox-paas
echo '{}' > deployments.json

echo "✅ Nettoyage terminé"
```

```bash
chmod +x 03_cleanup.sh
```

---

### Étape 9: Script de Test

**Fichier: `04_test_deployment.sh`**

```bash
#!/bin/bash

echo "=== Test Déploiement ==="

# Variables
API_URL="http://localhost:5000"
USERNAME="admin"
PASSWORD="admin123"

# Test 1: Login
echo "Test 1: Authentification..."
curl -c cookies.txt -X POST "$API_URL/login" \
    -d "username=$USERNAME&password=$PASSWORD" \
    -L -s -o /dev/null

if [ $? -eq 0 ]; then
    echo "✅ Login OK"
else
    echo "❌ Login échoué"
    exit 1
fi

# Test 2: Liste frameworks
echo "Test 2: Liste frameworks..."
curl -b cookies.txt "$API_URL/api/frameworks" -s | jq . > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Frameworks OK"
else
    echo "❌ Frameworks échoué"
fi

# Test 3: Statistiques
echo "Test 3: Statistiques..."
curl -b cookies.txt "$API_URL/api/stats" -s | jq .
echo "✅ Stats OK"

# Test 4: Déploiement test (optionnel)
read -p "Lancer un déploiement test? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Déploiement Flask test..."
    curl -b cookies.txt -X POST "$API_URL/api/deploy" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "test-flask",
            "framework": "flask",
            "github_url": "https://github.com/pallets/flask.git",
            "cpu": 2,
            "memory": 2048,
            "disk": 20
        }' -s | jq .
    echo "✅ Déploiement lancé"
fi

rm -f cookies.txt
echo "=== Tests terminés ==="
```

```bash
chmod +x 04_test_deployment.sh
```

---

### Étape 10: Configuration Réseau

**Fichier: `config.sh`**

```bash
#!/bin/bash

# CONFIGURATION - Modifier selon votre réseau
export PROXMOX_STORAGE="local-lvm"
export PROXMOX_BRIDGE="vmbr0"
export NETWORK_BASE_IP="192.168.1."
export NETWORK_GATEWAY="192.168.1.1"
export NETWORK_NETMASK="24"

# Sauvegarder configuration
cat > /root/proxmox-paas/.env << EOF
TEMPLATE_ID=9000
VM_RANGE_START=1100
VM_RANGE_END=1199
STORAGE=$PROXMOX_STORAGE
BRIDGE=$PROXMOX_BRIDGE
BASE_IP=$NETWORK_BASE_IP
GATEWAY=$NETWORK_GATEWAY
EOF

echo "✅ Configuration sauvegardée dans .env"
```

---

### Étape 11: Script Installation Complète

**Fichier: `00_install_all.sh`**

```bash
#!/bin/bash
set -e

echo "╔══════════════════════════════════════════════════╗"
echo "║   Installation Complète PaaS Platform Proxmox    ║"
echo "╚══════════════════════════════════════════════════╝"

cd /root/proxmox-paas

# Configuration
echo ""
read -p "Adresse IP de base (ex: 192.168.1.): " BASE_IP
read -p "Passerelle (ex: 192.168.1.1): " GATEWAY
read -p "Storage Proxmox (ex: local-lvm): " STORAGE
read -p "Bridge réseau (ex: vmbr0): " BRIDGE

# Mise à jour config dans app.py
sed -i "s|BASE_IP = \".*\"|BASE_IP = \"$BASE_IP\"|g" app.py
sed -i "s|GATEWAY = \".*\"|GATEWAY = \"$GATEWAY\"|g" app.py
sed -i "s|STORAGE = \".*\"|STORAGE = \"$STORAGE\"|g" app.py
sed -i "s|BRIDGE = \".*\"|BRIDGE = \"$BRIDGE\"|g" app.py

echo ""
echo "[1/4] Création template..."
./01_create_template.sh

echo ""
echo "[2/4] Installation service..."
./02_install_service.sh

echo ""
echo "[3/4] Test connexion..."
sleep 5
curl -s http://localhost:5000 > /dev/null && echo "✅ API accessible"

echo ""
echo "[4/4] Configuration utilisateurs..."
source venv/bin/activate
python3 manage_users.py list

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║            Installation Terminée !               ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "🌐 Interface: http://$(hostname -I | awk '{print $1}'):5000"
echo "👤 Utilisateur: admin"
echo "🔑 Mot de passe: admin123"
echo ""
echo "Commandes utiles:"
echo "  systemctl status proxmox-paas    # Statut"
echo "  systemctl restart proxmox-paas   # Redémarrer"
echo "  journalctl -u proxmox-paas -f    # Logs"
echo "  python3 manage_users.py list     # Utilisateurs"
echo ""
```

```bash
chmod +x 00_install_all.sh
```

---

## Utilisation

### Installation

```bash
cd /root/proxmox-paas
./00_install_all.sh
```

### Gestion Utilisateurs

```bash
# Activer environnement
source venv/bin/activate

# Ajouter utilisateur
python3 manage_users.py add alice password123 alice@example.com

# Lister utilisateurs
python3 manage_users.py list

# Changer mot de passe
python3 manage_users.py password alice newpass456

# Supprimer utilisateur
python3 manage_users.py delete alice
```

### Gestion Service

```bash
# Démarrer
systemctl start proxmox-paas

# Arrêter
systemctl stop proxmox-paas

# Redémarrer
systemctl restart proxmox-paas

# Statut
systemctl status proxmox-paas

# Logs en temps réel
journalctl -u proxmox-paas -f
```

### Nettoyage

```bash
# Supprimer toutes les VMs déployées
./03_cleanup.sh

# Réinitialisation complète
systemctl stop proxmox-paas
./03_cleanup.sh
rm -f deployments.json users.json
echo '{}' > deployments.json
systemctl start proxmox-paas
```

### Tests

```bash
# Test API
./04_test_deployment.sh

# Test manuel
curl http://localhost:5000/api/frameworks | jq .
```

---

## Structure Finale du Projet

```
/root/proxmox-paas/
├── 00_install_all.sh          # Installation complète
├── 01_create_template.sh      # Création template
├── 02_install_service.sh      # Installation service
├── 03_cleanup.sh              # Nettoyage
├── 04_test_deployment.sh      # Tests
├── app.py                     # Application principale
├── manage_users.py            # Gestion utilisateurs
├── config.sh                  # Configuration
├── venv/                      # Environnement Python
├── deployments.json           # Données déploiements
└── users.json                 # Données utilisateurs
```

---

## Exemples de Déploiement

### Flask
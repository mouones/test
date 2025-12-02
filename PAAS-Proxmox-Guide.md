# Développement d’une Plateforme PaaS Privée Basée sur Proxmox VE 6.14

Ce guide documente la création complète d’une plateforme PaaS privée s’appuyant sur **Proxmox VE 6.14**, **Terraform**, une **API Flask** et des **scripts Bash** permettant de déployer automatiquement des applications issues de dépôts GitHub.

> ⚠️ Les exemples utilisent des identifiants de démonstration (`admin` / `Admin!123`). Changez-les impérativement avant toute mise en production et stockez vos secrets dans un gestionnaire dédié (Vault, Azure Key Vault, etc.).

---

## 1. Vision d’ensemble

| Composant | Rôle |
| --- | --- |
| Proxmox VE 6.14 | Hyperviseur de virtualisation (VM QEMU & conteneurs LXC) |
| Terraform | Automatisation de l’orchestration Proxmox (provider Telmate) |
| Flask API | Reçoit les demandes utilisateur, génère les variables, lance Terraform et les scripts post-déploiement |
| Scripts Bash | Installation des frameworks & déploiement applicatif dans la VM/LXC |
| GitHub | Source des projets applicatifs à déployer |

Flux global :

```
Utilisateur → Interface Flask → Terraform → Proxmox → VM/LXC → Scripts install_framework / deploy_app → App accessible
```

---

## 2. Prérequis

- Cluster Proxmox VE 6.14 opérationnel, accès API actif.
- Un compte API dédié : `terraform@pam` (ou `terraform@pve`) avec un mot de passe fort et les ACL nécessaires.
- Un template VM (ex. ID `9000`) généré avec cloud-init et les packages de base.
- Machine d’orchestration (peut être un conteneur Debian/Ubuntu) disposant de :
  - `terraform >= 1.4`
  - `python3 >= 3.9`, `pip`, `virtualenv`
  - `git`, `curl`, `jq`, `openssh-client`

Installation rapide sur Debian/Ubuntu :

```bash
apt-get update
apt-get install -y unzip curl wget git python3 python3-venv python3-pip jq
wget https://releases.hashicorp.com/terraform/1.4.6/terraform_1.4.6_linux_amd64.zip -O /tmp/terraform.zip
unzip /tmp/terraform.zip -d /usr/local/bin
python3 -m venv /opt/paas/venv
source /opt/paas/venv/bin/activate
pip install --upgrade pip
pip install flask python-terraform
```

---

## 3. Structure du projet

```
paas-proxmox/
├── app.py                     # API Flask
├── requirements.txt
├── terraform_template/
│   ├── providers.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── cloud-init.cfg
├── scripts/
│   ├── install_framework.sh
│   └── deploy_app.sh
└── README.md (optionnel)
```

---

## 4. Backend Flask (`app.py`)

Ce backend expose `/deploy`. Il reçoit le type de machine (vm/lxc), le framework, l’URL GitHub et crée un espace de travail Terraform temporaire.

```python
#!/usr/bin/env python3
import json
import os
import shutil
import subprocess
import tempfile
import uuid
from pathlib import Path
from flask import Flask, request, jsonify

WORKDIR = Path(__file__).parent.resolve()
TEMPLATE_DIR = WORKDIR / "terraform_template"
TERRAFORM_BIN = shutil.which("terraform") or "/usr/local/bin/terraform"

app = Flask(__name__)
app.config['API_USER'] = 'admin'
app.config['API_PASSWORD'] = 'Admin!123'  # À remplacer immédiatement


def run(cmd, cwd=None):
    result = subprocess.run(cmd, cwd=cwd, check=True, capture_output=True, text=True)
    return result.stdout.strip()


def copy_template(dest: Path):
    shutil.copytree(TEMPLATE_DIR, dest / "terraform", dirs_exist_ok=True)


@app.route('/deploy', methods=['POST'])
def deploy():
    auth = request.authorization
    if not auth or auth.username != app.config['API_USER'] or auth.password != app.config['API_PASSWORD']:
        return jsonify({'error': 'Unauthorized'}), 401

    payload = request.get_json(force=True)
    for field in ('name', 'repo', 'framework', 'machine_type'):
        if field not in payload:
            return jsonify({'error': f"Missing field '{field}'"}), 400

    work_id = uuid.uuid4().hex[:8]
    tmpdir = Path(tempfile.mkdtemp(prefix=f"deploy-{work_id}-"))
    copy_template(tmpdir)

    tfvars = {
        'vm_name': payload['name'],
        'repo_url': payload['repo'],
        'framework': payload['framework'],
        'machine_type': payload['machine_type'],
    }
    (tmpdir / 'terraform' / 'terraform.tfvars.json').write_text(json.dumps(tfvars, indent=2))

    # Terraform
    tf_dir = tmpdir / 'terraform'
    run([TERRAFORM_BIN, 'init'], cwd=tf_dir)
    run([TERRAFORM_BIN, 'apply', '-auto-approve'], cwd=tf_dir)
    outputs = json.loads(run([TERRAFORM_BIN, 'output', '-json'], cwd=tf_dir))

    # Nettoyage selon vos besoins (laisser ici pour audit si nécessaire)
    return jsonify({'status': 'success', 'workspace': str(tmpdir), 'outputs': outputs})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

`requirements.txt` :

```
flask
python-terraform
```

---

## 5. Terraform pour Proxmox (`terraform_template/`)

### 5.1 `providers.tf`

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = ">= 2.9.6"
    }
  }
}

provider "proxmox" {
  pm_api_url      = var.proxmox_api_url
  pm_user         = var.proxmox_user
  pm_password     = var.proxmox_password
  pm_tls_insecure = true
}
```

### 5.2 `variables.tf`

```hcl
variable "proxmox_api_url" {}
variable "proxmox_user" {}
variable "proxmox_password" {}
variable "vm_name" {}
variable "repo_url" {}
variable "framework" {}
variable "machine_type" { default = "lxc" } # lxc ou vm
variable "template_id" { default = 9000 }
variable "target_node" { default = "pve" }
variable "vm_id" { default = 1200 }
variable "storage" { default = "local-lvm" }
variable "bridge" { default = "vmbr0" }
```

### 5.3 `main.tf`

```hcl
locals {
  is_lxc = lower(var.machine_type) == "lxc"
}

resource "proxmox_lxc" "paas" {
  count     = local.is_lxc ? 1 : 0
  hostname  = var.vm_name
  ostemplate= "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  password  = "Admin!123" # MOT DE PASSE D’EXEMPLE → À ROTATION
  unprivileged = true
  cores     = 2
  memory    = 2048
  rootfs    = "local-lvm:8"
  target_node = var.target_node
  net {
    name = "eth0"
    bridge = var.bridge
    ip = "dhcp"
  }
}

resource "proxmox_vm_qemu" "paas" {
  count       = local.is_lxc ? 0 : 1
  name        = var.vm_name
  vmid        = var.vm_id
  target_node = var.target_node
  clone       = var.template_id
  cores       = 2
  sockets     = 1
  memory      = 2048
  scsihw      = "virtio-scsi-pci"
  disk {
    slot     = 0
    size     = "32G"
    type     = "scsi"
    storage  = var.storage
  }
  network {
    model  = "virtio"
    bridge = var.bridge
  }
  agent = 1
  ciuser = "admin"
  cipassword = "Admin!123"
  sshkeys = file("~/.ssh/id_rsa.pub")
}

output "vm_ip" {
  value = local.is_lxc ? proxmox_lxc.paas[0].network[0].ip : proxmox_vm_qemu.paas[0].default_ipv4_address
}
```

### 5.4 `cloud-init.cfg`

```yaml
#cloud-config
users:
  - name: admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    lock_passwd: false
    plain_text_passwd: "Admin!123"
ssh_pwauth: true
packages:
  - git
  - python3
  - python3-venv
  - python3-pip
  - nodejs
  - npm
  - php
  - composer
  - nginx
runcmd:
  - [ bash, -c, 'echo "Cloud-init terminé" >/var/log/cloudinit.done' ]
```

---

## 6. Scripts Bash (`scripts/`)

### 6.1 `install_framework.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
FRAMEWORK="${1:-django}"
APP_DIR="${2:-/opt/app}"

log() {
  echo "[install] $1"
}

apt-get update

case "$FRAMEWORK" in
  django|flask)
    log "Installation stack Python"
    apt-get install -y python3-venv python3-dev build-essential
    ;;
  node|nodejs|express|react|vue)
    log "Installation stack Node.js"
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
    ;;
  laravel|php)
    log "Installation stack PHP/Laravel"
    apt-get install -y php php-cli php-fpm php-mysql php-xml php-mbstring php-curl php-zip composer nginx
    ;;
  docker)
    log "Installation Docker"
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker admin
    ;;
  *)
    echo "Framework inconnu: $FRAMEWORK" >&2
    exit 1
    ;;
 esac

echo "Framework $FRAMEWORK prêt dans $APP_DIR"
```

### 6.2 `deploy_app.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
REPO_URL="$1"
FRAMEWORK="$2"
APP_BASE="/opt/apps"
APP_NAME=$(basename "$REPO_URL" .git)
APP_DIR="$APP_BASE/$APP_NAME"

mkdir -p "$APP_BASE"
if [ ! -d "$APP_DIR/.git" ]; then
  git clone "$REPO_URL" "$APP_DIR"
else
  git -C "$APP_DIR" pull --ff-only
fi

case "$FRAMEWORK" in
  django|flask)
    cd "$APP_DIR"
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt || true
    if [ "$FRAMEWORK" = "django" ]; then
      python manage.py migrate --noinput || true
      nohup python manage.py runserver 0.0.0.0:8000 >/var/log/${APP_NAME}.log 2>&1 &
    else
      nohup python app.py >/var/log/${APP_NAME}.log 2>&1 &
    fi
    ;;
  node|nodejs|express|react|vue)
    cd "$APP_DIR"
    npm install || true
    if [ "$FRAMEWORK" = "react" ] || [ "$FRAMEWORK" = "vue" ]; then
      npm run build || true
      npx serve -s build -l 80 >/var/log/${APP_NAME}.log 2>&1 &
    else
      nohup npm start >/var/log/${APP_NAME}.log 2>&1 &
    fi
    ;;
  laravel|php)
    cd "$APP_DIR"
    composer install --no-dev --optimize-autoloader || true
    cp .env.example .env 2>/dev/null || true
    php artisan key:generate || true
    chown -R www-data:www-data "$APP_DIR"
    cat >/etc/nginx/sites-enabled/default <<EOF
server {
    listen 80 default_server;
    root $APP_DIR/public;
    index index.php index.html;
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
    }
}
EOF
    systemctl restart nginx php8.2-fpm
    ;;
  docker)
    cd "$APP_DIR"
    if [ -f docker-compose.yml ]; then
      docker compose up -d
    elif [ -f Dockerfile ]; then
      docker build -t "$APP_NAME" .
      docker run -d -p 80:80 --name "$APP_NAME" "$APP_NAME"
    fi
    ;;
  *)
    echo "Framework $FRAMEWORK non supporté" >&2
    exit 1
    ;;
esac

echo "Application déployée : $APP_NAME"
```

Rendez les scripts exécutables :

```bash
chmod +x scripts/install_framework.sh scripts/deploy_app.sh
```

---

## 7. Secrets & Variables

Créez un fichier `terraform_template/secrets.auto.tfvars` (non versionné) :

```hcl
proxmox_api_url = "https://proxmox.example.com:8006/api2/json"
proxmox_user    = "terraform@pam"
proxmox_password= "MotDePasseTrèsFort123!"
```

Pour tester le template seul :

```bash
cd terraform_template
terraform init
terraform apply -auto-approve
```

---

## 8. API Flask : lancement & test

```bash
cd /opt/paas
source venv/bin/activate
export FLASK_APP=app.py
flask run --host=0.0.0.0 --port=5000
```

Test de déploiement :

```bash
curl -u admin:Admin!123 \
     -H "Content-Type: application/json" \
     -X POST http://<IP_API>:5000/deploy \
     -d '{
          "name": "proj-demo-01",
          "repo": "https://github.com/example/django-sample.git",
          "framework": "django",
          "machine_type": "vm"
         }'
```

Réponse attendue : IP de la machine, workspace Terraform, état.

---

## 9. Chaîne complète (résumé)

1. **Utilisateur** choisit : VM/LXC, framework (Django, Laravel, Node.js, etc.), URL GitHub.
2. **Flask** valide la requête, génère `terraform.tfvars`, appelle Terraform.
3. **Terraform** clone le template Proxmox et crée la VM/LXC.
4. **Cloud-init / scripts** installent les dépendances (`install_framework.sh`).
5. **deploy_app.sh** clone le dépôt, installe les packages, lance l’application.
6. **API** renvoie IP/ports/identifiants au demandeur.

---

## 10. Sécurité & bonnes pratiques

- Changer tous les mots de passe d’exemple (`Admin!123`).
- Restreindre les ACL Proxmox : le compte Terraform ne doit gérer que les VMID autorisés.
- Ajouter TLS, authentification forte et quotas côté Flask.
- Utiliser Ansible/CI pour auditer les scripts et éviter les dérives.
- Journaliser les déploiements (`deployments.json`, base SQL, etc.).

---

## 11. Aller plus loin

- Ajouter une base de données (PostgreSQL, MySQL) automatiquement via Terraform modules.
- Intégrer un front-end (React, Vue) consommant l’API Flask.
- Ajouter un système de tickets & rôles utilisateurs (Flask-Login, OAuth2).
- Publier les métriques (Prometheus) et alertes (Grafana, Alertmanager).

---

Ce document sert de base pour industrialiser un PaaS interne sur Proxmox VE 6.14. Adaptez les tailles, réseaux, ACL et scripts à vos contraintes, testez chaque brique isolément puis enchaînez les déploiements automatiques pour vos applications internes. Bonne construction !

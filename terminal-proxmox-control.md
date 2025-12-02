# Guide de Contrôle Proxmox via Terminal SSH

Ce guide complet vous permet de contrôler et gérer votre plateforme PaaS Proxmox 6.14 directement depuis le terminal SSH.

---

## 1. Connexion SSH à Proxmox

```bash
# Connexion SSH en tant que root
ssh root@<IP_PROXMOX>

# Exemple avec IP
ssh root@192.168.1.100

# Avec clé SSH (recommandé)
ssh -i ~/.ssh/id_rsa root@<IP_PROXMOX>
```

**Identifiants par défaut** (selon documentation) :
- Utilisateur : `root`
- Mot de passe : celui défini lors de l'installation Proxmox

---

## 2. Commandes de Base Proxmox

### 2.1 Lister les VMs et Conteneurs

```bash
# Lister toutes les VMs
qm list

# Lister tous les conteneurs LXC
pct list

# Afficher les détails d'une VM spécifique
qm status <VMID>
qm config <VMID>

# Afficher les détails d'un conteneur LXC
pct status <CTID>
pct config <CTID>
```

### 2.2 Gestion des Templates

```bash
# Vérifier si le template 9000 existe
qm status 9000

# Lister tous les templates
qm list | grep template

# Afficher la configuration du template
qm config 9000
```

### 2.3 Créer une VM depuis le Template

```bash
# Cloner le template pour créer une nouvelle VM
qm clone 9000 1100 --name "app-demo-01" --full

# Démarrer la VM
qm start 1100

# Obtenir l'IP de la VM (attendre que l'agent soit prêt)
qm guest cmd 1100 network-get-interfaces

# Alternative : via cloud-init
qm cloudinit dump 1100 user
```

### 2.4 Contrôle des VMs

```bash
# Démarrer une VM
qm start <VMID>

# Arrêter une VM (proprement)
qm shutdown <VMID>

# Arrêter force
qm stop <VMID>

# Redémarrer
qm reboot <VMID>

# Suspendre
qm suspend <VMID>

# Reprendre
qm resume <VMID>

# Détruire (ATTENTION : suppression définitive)
qm destroy <VMID> --purge
```

### 2.5 Configuration Cloud-Init

```bash
# Configurer l'utilisateur et mot de passe
qm set <VMID> --ciuser root
qm set <VMID> --cipassword $(openssl passwd -6 "VotreMotDePasse")

# Configurer le réseau
qm set <VMID> --ipconfig0 ip=dhcp
# Ou IP statique
qm set <VMID> --ipconfig0 ip=192.168.1.150/24,gw=192.168.1.1

# Ajouter une clé SSH
qm set <VMID> --sshkeys ~/.ssh/id_rsa.pub

# Configurer DNS
qm set <VMID> --nameserver 8.8.8.8

# Redémarrer pour appliquer cloud-init
qm reboot <VMID>
```

---

## 3. Installation de la Plateforme PaaS

### 3.1 Configuration Initiale

```bash
# Se connecter à Proxmox
ssh root@<IP_PROXMOX>

# Mettre à jour le système
apt-get update
apt-get upgrade -y

# Installer les dépendances
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

### 3.2 Créer le Répertoire du Projet

```bash
# Créer le dossier principal
mkdir -p /root/proxmox-paas
cd /root/proxmox-paas

# Créer l'environnement virtuel Python
python3 -m venv venv
source venv/bin/activate

# Installer Flask et dépendances
pip install flask flask-login werkzeug
```

### 3.3 Créer le Template VM Universal

Créez le fichier de script :

```bash
cat > 01_create_template.sh << 'EOF'
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

echo "✅ Template $TEMPLATE_ID créé avec succès"
EOF
```

Exécuter le script :

```bash
chmod +x 01_create_template.sh
./01_create_template.sh
```

---

## 4. Déploiement Manuel d'une Application

### 4.1 Créer une VM depuis le Template

```bash
# Variables
VMID=1100
VM_NAME="django-app-01"
TEMPLATE_ID=9000

# Cloner le template
qm clone $TEMPLATE_ID $VMID --name "$VM_NAME" --full

# Configurer les ressources
qm set $VMID --cores 2 --memory 2048

# Configurer cloud-init
qm set $VMID --ciuser root
qm set $VMID --cipassword $(openssl passwd -6 "AppPass123!")
qm set $VMID --ipconfig0 ip=dhcp
qm set $VMID --nameserver 8.8.8.8

# Démarrer la VM
qm start $VMID

# Attendre que la VM soit prête (environ 30-60 secondes)
sleep 60

# Obtenir l'IP (avec qemu-guest-agent)
VM_IP=$(qm guest cmd $VMID network-get-interfaces | jq -r '.[] | select(.name == "eth0") | .["ip-addresses"][] | select(.["ip-address-type"] == "ipv4") | .["ip-address"]' | head -n1)
echo "VM IP: $VM_IP"
```

### 4.2 Déployer une Application Django

```bash
# SSH vers la VM
ssh -o StrictHostKeyChecking=no root@$VM_IP

# Dans la VM :
cd /opt
git clone https://github.com/votre-user/votre-app-django.git app
cd app

# Créer environnement virtuel
python3 -m venv venv
source venv/bin/activate

# Installer dépendances
pip install -r requirements.txt

# Migration Django
python manage.py migrate

# Lancer l'application
nohup python manage.py runserver 0.0.0.0:8000 > /var/log/app.log 2>&1 &

# Vérifier les logs
tail -f /var/log/app.log
```

### 4.3 Déployer une Application Node.js

```bash
ssh root@$VM_IP

cd /opt
git clone https://github.com/votre-user/votre-app-nodejs.git app
cd app

# Installer dépendances
npm install

# Lancer l'application
PORT=3000 nohup npm start > /var/log/app.log 2>&1 &

# Vérifier
tail -f /var/log/app.log
```

### 4.4 Déployer une Application Laravel

```bash
ssh root@$VM_IP

cd /opt
git clone https://github.com/votre-user/votre-app-laravel.git app
cd app

# Installer dépendances
composer install --optimize-autoloader --no-dev

# Configuration
cp .env.example .env
php artisan key:generate

# Permissions
chown -R www-data:www-data /opt/app

# Configurer Nginx
cat > /etc/nginx/sites-enabled/default << 'NGINX_EOF'
server {
    listen 80 default_server;
    root /opt/app/public;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
NGINX_EOF

# Redémarrer Nginx
systemctl restart nginx php8.2-fpm
```

---

## 5. Monitoring et Gestion

### 5.1 Surveiller les Ressources

```bash
# CPU et RAM de toutes les VMs
qm list

# Détails d'utilisation d'une VM
qm monitor <VMID>

# Utilisation disque
pvesm status

# Voir les logs système Proxmox
journalctl -u pve-cluster -f
journalctl -u pvedaemon -f
```

### 5.2 Logs des VMs

```bash
# Logs de démarrage d'une VM
qm showcmd <VMID>

# Console série (si configurée)
qm terminal <VMID>
```

### 5.3 SSH vers les VMs

```bash
# Lister les IPs des VMs
for vmid in $(qm list | tail -n +2 | awk '{print $1}'); do
    echo -n "VM $vmid: "
    qm guest cmd $vmid network-get-interfaces 2>/dev/null | jq -r '.[] | select(.name == "eth0") | .["ip-addresses"][] | select(.["ip-address-type"] == "ipv4") | .["ip-address"]' | head -n1
done

# SSH automatique
VM_IP=$(qm guest cmd <VMID> network-get-interfaces | jq -r '.[] | select(.name == "eth0") | .["ip-addresses"][] | select(.["ip-address-type"] == "ipv4") | .["ip-address"]' | head -n1)
ssh root@$VM_IP
```

---

## 6. Scripts d'Automatisation

### 6.1 Script de Déploiement Complet

Créez `/root/proxmox-paas/deploy_app.sh` :

```bash
#!/bin/bash
set -e

# Configuration
TEMPLATE_ID=9000
VMID_START=1100
GITHUB_REPO="$1"
FRAMEWORK="$2"
APP_NAME="$3"

if [ -z "$GITHUB_REPO" ] || [ -z "$FRAMEWORK" ] || [ -z "$APP_NAME" ]; then
    echo "Usage: $0 <github_repo> <framework> <app_name>"
    echo "Frameworks: django|flask|nodejs|laravel|react|vue|docker"
    exit 1
fi

# Trouver le prochain VMID disponible
VMID=$VMID_START
while qm status $VMID &>/dev/null; do
    VMID=$((VMID + 1))
done

echo "=== Déploiement de $APP_NAME ==="
echo "VMID: $VMID"
echo "Framework: $FRAMEWORK"
echo "Repo: $GITHUB_REPO"

# Cloner le template
qm clone $TEMPLATE_ID $VMID --name "$APP_NAME" --full

# Configurer
qm set $VMID --cores 2 --memory 2048
qm set $VMID --ciuser root
qm set $VMID --cipassword $(openssl passwd -6 "AppPass123")
qm set $VMID --ipconfig0 ip=dhcp

# Démarrer
qm start $VMID

# Attendre
echo "Attente du démarrage de la VM..."
sleep 60

# Obtenir IP
VM_IP=$(qm guest cmd $VMID network-get-interfaces 2>/dev/null | jq -r '.[] | select(.name == "eth0") | .["ip-addresses"][] | select(.["ip-address-type"] == "ipv4") | .["ip-address"]' | head -n1)

if [ -z "$VM_IP" ]; then
    echo "Erreur: impossible d'obtenir l'IP"
    exit 1
fi

echo "VM IP: $VM_IP"

# Déployer selon le framework
case $FRAMEWORK in
    django|flask)
        ssh -o StrictHostKeyChecking=no root@$VM_IP << DEPLOY_EOF
cd /opt
git clone $GITHUB_REPO app
cd app
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
if [ "$FRAMEWORK" = "django" ]; then
    python manage.py migrate
    nohup python manage.py runserver 0.0.0.0:8000 > /var/log/app.log 2>&1 &
else
    nohup python app.py > /var/log/app.log 2>&1 &
fi
DEPLOY_EOF
        ;;
    
    nodejs)
        ssh -o StrictHostKeyChecking=no root@$VM_IP << DEPLOY_EOF
cd /opt
git clone $GITHUB_REPO app
cd app
npm install
PORT=3000 nohup npm start > /var/log/app.log 2>&1 &
DEPLOY_EOF
        ;;
    
    laravel)
        ssh -o StrictHostKeyChecking=no root@$VM_IP << DEPLOY_EOF
cd /opt
git clone $GITHUB_REPO app
cd app
composer install --no-dev
cp .env.example .env
php artisan key:generate
chown -R www-data:www-data /opt/app
cat > /etc/nginx/sites-enabled/default << 'NGINX_EOF'
server {
    listen 80 default_server;
    root /opt/app/public;
    index index.php index.html;
    location / { try_files \$uri \$uri/ /index.php?\$query_string; }
    location ~ \.php\$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
NGINX_EOF
systemctl restart nginx php8.2-fpm
DEPLOY_EOF
        ;;
esac

echo "✅ Déploiement terminé!"
echo "URL: http://$VM_IP"
echo "VMID: $VMID"
```

Utilisation :

```bash
chmod +x deploy_app.sh
./deploy_app.sh https://github.com/user/django-app django mon-app-01
```

### 6.2 Script de Suppression

```bash
#!/bin/bash
# delete_vm.sh
VMID="$1"

if [ -z "$VMID" ]; then
    echo "Usage: $0 <VMID>"
    exit 1
fi

echo "Suppression de la VM $VMID..."
qm stop $VMID 2>/dev/null || true
sleep 3
qm destroy $VMID --purge

echo "✅ VM $VMID supprimée"
```

---

## 7. Identifiants et Accès

### Proxmox Web Interface
- URL : `https://<IP_PROXMOX>:8006`
- Utilisateur : `root@pam`
- Mot de passe : défini lors de l'installation

### Template VM (ID 9000)
- Utilisateur : `root`
- Mot de passe : `rootpass123` (à changer en production)

### VMs Déployées
- Utilisateur : `root`
- Mot de passe : défini via cloud-init (ex: `AppPass123`)

### API Flask (si déployée)
- URL : `http://<IP_PROXMOX>:5000`
- Utilisateur : `admin`
- Mot de passe : `admin123`

---

## 8. Dépannage

### VM ne démarre pas

```bash
# Vérifier les logs
qm showcmd <VMID>
journalctl -u qemu-server@<VMID>

# Réinitialiser
qm reset <VMID>
```

### Impossible d'obtenir l'IP

```bash
# Vérifier l'agent QEMU
qm agent <VMID> ping

# Redémarrer l'agent
ssh root@<IP_VM>
systemctl restart qemu-guest-agent

# Alternative : utiliser l'interface web Proxmox
```

### Problème de permissions

```bash
# Depuis Proxmox host
pveum user list
pveum aclmod / -user root@pam -role Administrator
```

---

## 9. Commandes Rapides de Référence

```bash
# Lister VMs
qm list

# Créer VM depuis template
qm clone 9000 <NEW_VMID> --name "<NAME>" --full

# Démarrer/Arrêter
qm start <VMID>
qm shutdown <VMID>

# Configuration
qm config <VMID>
qm set <VMID> --cores 4 --memory 4096

# IP d'une VM
qm guest cmd <VMID> network-get-interfaces | jq

# SSH rapide
ssh root@$(qm guest cmd <VMID> network-get-interfaces | jq -r '.[] | select(.name == "eth0") | .["ip-addresses"][] | select(.["ip-address-type"] == "ipv4") | .["ip-address"]' | head -n1)

# Supprimer VM
qm destroy <VMID> --purge

# Status cluster
pvecm status

# Storage
pvesm status
```

---

## 10. Sécurité et Meilleures Pratiques

1. **Changez tous les mots de passe par défaut**
2. **Utilisez des clés SSH** au lieu de mots de passe
3. **Configurez un firewall** sur Proxmox et les VMs
4. **Faites des sauvegardes régulières**
5. **Limitez l'accès SSH** aux IPs de confiance
6. **Utilisez HTTPS** pour l'interface web Proxmox
7. **Surveillez les ressources** (CPU, RAM, disque)
8. **Mettez à jour régulièrement** Proxmox et les VMs

---

Ce guide vous permet de contrôler complètement votre plateforme PaaS Proxmox via le terminal SSH !

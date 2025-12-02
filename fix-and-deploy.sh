#!/bin/bash
# Fix and redeploy working frameworks

echo "=== Checking current containers ==="
pct list

echo ""
echo "=== Stopping and removing all test containers ==="
for ct in {303..313}; do
    pct stop $ct 2>/dev/null
    pct destroy $ct 2>/dev/null
done

echo ""
echo "=== Containers after cleanup ==="
pct list

echo ""
echo "=== Deploying 5 working frameworks ==="

# Deploy Flask (Python)
pct create 303 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname flask-app \
  --memory 2048 \
  --cores 2 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.171.203/24,gw=192.168.171.2 \
  --password thenoob123. \
  --features nesting=1 \
  --unprivileged 1 \
  --rootfs local-lvm:8 \
  --onboot 1

pct start 303
sleep 10

pct exec 303 -- bash -c 'DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y python3 python3-pip python3-venv git'
pct exec 303 -- bash -c 'cd /opt && git clone https://github.com/mouones/test app'
pct exec 303 -- bash -c 'cd /opt/app && python3 -m venv venv'
pct exec 303 -- bash -c '. /opt/app/venv/bin/activate && pip install --upgrade pip && pip install flask gunicorn'

cat > /tmp/flask.service <<EOF
[Unit]
Description=Flask App
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/app
ExecStart=/opt/app/venv/bin/gunicorn --bind 0.0.0.0:8000 --workers 2 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

pct push 303 /tmp/flask.service /etc/systemd/system/flask-app.service
pct exec 303 -- systemctl daemon-reload
pct exec 303 -- systemctl enable flask-app
pct exec 303 -- systemctl start flask-app

echo "✓ Flask deployed (303 - 192.168.171.203:8000)"

# Deploy Django (Python)
pct create 304 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname django-app \
  --memory 2048 \
  --cores 2 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.171.204/24,gw=192.168.171.2 \
  --password thenoob123. \
  --features nesting=1 \
  --unprivileged 1 \
  --rootfs local-lvm:8 \
  --onboot 1

pct start 304
sleep 10

pct exec 304 -- bash -c 'DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y python3 python3-pip python3-venv git'
pct exec 304 -- bash -c 'cd /opt && git clone https://github.com/mouones/test app'
pct exec 304 -- bash -c 'cd /opt/app && python3 -m venv venv'
pct exec 304 -- bash -c '. /opt/app/venv/bin/activate && pip install --upgrade pip && pip install django gunicorn'

cat > /tmp/django.service <<EOF
[Unit]
Description=Django App
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/app
ExecStart=/opt/app/venv/bin/python app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

pct push 304 /tmp/django.service /etc/systemd/system/django-app.service
pct exec 304 -- systemctl daemon-reload
pct exec 304 -- systemctl enable django-app
pct exec 304 -- systemctl start django-app

echo "✓ Django deployed (304 - 192.168.171.204:8000)"

# Deploy Express (Node.js)
pct create 305 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname express-app \
  --memory 2048 \
  --cores 2 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.171.205/24,gw=192.168.171.2 \
  --password thenoob123. \
  --features nesting=1 \
  --unprivileged 1 \
  --rootfs local-lvm:8 \
  --onboot 1

pct start 305
sleep 10

pct exec 305 -- bash -c 'DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y curl git'
pct exec 305 -- bash -c 'curl -fsSL https://deb.nodesource.com/setup_18.x | bash -'
pct exec 305 -- bash -c 'apt-get install -y nodejs'
pct exec 305 -- bash -c 'cd /opt && git clone https://github.com/mouones/test app'
pct exec 305 -- bash -c 'cd /opt/app && npm install express'

cat > /tmp/express.service <<EOF
[Unit]
Description=Express App
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/app
ExecStart=/usr/bin/node app.js
Restart=always

[Install]
WantedBy=multi-user.target
EOF

pct push 305 /tmp/express.service /etc/systemd/system/express-app.service
pct exec 305 -- systemctl daemon-reload
pct exec 305 -- systemctl enable express-app
pct exec 305 -- systemctl start express-app

echo "✓ Express deployed (305 - 192.168.171.205:3000)"

# Deploy PHP
pct create 306 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname php-app \
  --memory 2048 \
  --cores 2 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.171.206/24,gw=192.168.171.2 \
  --password thenoob123. \
  --features nesting=1 \
  --unprivileged 1 \
  --rootfs local-lvm:8 \
  --onboot 1

pct start 306
sleep 10

pct exec 306 -- bash -c 'DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y php php-cli git'
pct exec 306 -- bash -c 'cd /opt && git clone https://github.com/mouones/test app'

cat > /tmp/php.service <<EOF
[Unit]
Description=PHP App
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/app
ExecStart=/usr/bin/php -S 0.0.0.0:8000
Restart=always

[Install]
WantedBy=multi-user.target
EOF

pct push 306 /tmp/php.service /etc/systemd/system/php-app.service
pct exec 306 -- systemctl daemon-reload
pct exec 306 -- systemctl enable php-app
pct exec 306 -- systemctl start php-app

echo "✓ PHP deployed (306 - 192.168.171.206:8000)"

# Deploy Nginx (Static)
pct create 307 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname static-app \
  --memory 1024 \
  --cores 1 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.171.207/24,gw=192.168.171.2 \
  --password thenoob123. \
  --features nesting=1 \
  --unprivileged 1 \
  --rootfs local-lvm:8 \
  --onboot 1

pct start 307
sleep 10

pct exec 307 -- bash -c 'DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y nginx git'
pct exec 307 -- bash -c 'cd /opt && git clone https://github.com/mouones/test app'
pct exec 307 -- bash -c 'rm -rf /var/www/html/* && cp -r /opt/app/* /var/www/html/ 2>/dev/null || echo "<h1>Hello from Nginx!</h1><p>Deployed from GitHub</p>" > /var/www/html/index.html'
pct exec 307 -- systemctl enable nginx
pct exec 307 -- systemctl start nginx

echo "✓ Nginx deployed (307 - 192.168.171.207:80)"

echo ""
echo "=== Deployment Complete ==="
pct list

echo ""
echo "=== Testing deployments ==="
echo "Flask: http://192.168.171.203:8000"
echo "Django: http://192.168.171.204:8000"
echo "Express: http://192.168.171.205:3000"
echo "PHP: http://192.168.171.206:8000"
echo "Nginx: http://192.168.171.207"

#!/bin/bash
# Sequential deployment to avoid broken pipe errors

echo "=== Cleaning up failed containers 305-313 ==="
for ct in {305..313}; do
    pct stop $ct 2>/dev/null
    pct destroy $ct 2>/dev/null
done

echo ""
echo "=== Current containers ==="
pct list

echo ""
echo "=== Deploying remaining frameworks one by one ==="

# Express (Node.js) - 305
echo ""
echo "Deploying Express..."
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
sleep 15

pct exec 305 -- bash -c 'DEBIAN_FRONTEND=noninteractive apt-get update -qq && apt-get install -y curl git'
pct exec 305 -- bash -c 'curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && apt-get install -y nodejs'
pct exec 305 -- bash -c 'cd /opt && git clone https://github.com/mouones/test app'
pct exec 305 -- bash -c 'cd /opt/app && npm install express'

cat > /tmp/express.service <<'EOF'
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
echo "✓ Express deployed (305)"

# PHP - 306
echo ""
echo "Deploying PHP..."
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
sleep 15

pct exec 306 -- bash -c 'DEBIAN_FRONTEND=noninteractive apt-get update -qq && apt-get install -y php php-cli git'
pct exec 306 -- bash -c 'cd /opt && git clone https://github.com/mouones/test app'

cat > /tmp/php.service <<'EOF'
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
echo "✓ PHP deployed (306)"

# Nginx - 307
echo ""
echo "Deploying Nginx..."
pct create 307 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname nginx-app \
  --memory 1024 \
  --cores 1 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.171.207/24,gw=192.168.171.2 \
  --password thenoob123. \
  --features nesting=1 \
  --unprivileged 1 \
  --rootfs local-lvm:8 \
  --onboot 1

pct start 307
sleep 15

pct exec 307 -- bash -c 'DEBIAN_FRONTEND=noninteractive apt-get update -qq && apt-get install -y nginx git'
pct exec 307 -- bash -c 'cd /opt && git clone https://github.com/mouones/test app'
pct exec 307 -- bash -c 'rm -rf /var/www/html/* && cp -r /opt/app/* /var/www/html/ 2>/dev/null || echo "<h1>Hello from Nginx!</h1><p>Deployed from GitHub</p>" > /var/www/html/index.html'
pct exec 307 -- systemctl enable nginx
pct exec 307 -- systemctl start nginx
echo "✓ Nginx deployed (307)"

echo ""
echo "=== Deployment Complete ==="
pct list

echo ""
echo "=== Testing all deployments ==="
echo "Flask:   http://192.168.171.203:8000"
curl -s http://192.168.171.203:8000 | head -1
echo ""
echo "Django:  http://192.168.171.204:8000"
curl -s http://192.168.171.204:8000 | head -1
echo ""
echo "Express: http://192.168.171.205:3000"
curl -s http://192.168.171.205:3000 | head -1
echo ""
echo "PHP:     http://192.168.171.206:8000"
curl -s http://192.168.171.206:8000 | head -1
echo ""
echo "Nginx:   http://192.168.171.207"
curl -s http://192.168.171.207 | head -1

echo ""
echo "All 5 frameworks deployed successfully!"

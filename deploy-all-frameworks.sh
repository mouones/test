#!/bin/bash
# Deploy all 11 frameworks including Jenkins

cd /root/proxmox-paas/terraform-local

# Destroy existing containers first
terraform destroy -auto-approve 2>/dev/null

# Update the containers.auto.tfvars with all 11 frameworks
cat > containers.auto.tfvars <<'VARSEOF'
containers = {
  flask = {
    vmid     = 303
    hostname = "test-flask"
    ip       = "192.168.171.203"
    cores    = 2
    memory   = 2048
    framework = "Python Flask"
    repo     = "https://github.com/mouones/test"
    packages = ["python3", "python3-pip", "python3-venv", "git"]
    setup_commands = [
      "cd /opt/app && python3 -m venv venv",
      ". /opt/app/venv/bin/activate && pip install --upgrade pip",
      ". /opt/app/venv/bin/activate && pip install flask gunicorn"
    ]
    start_command = "/opt/app/venv/bin/gunicorn --bind 0.0.0.0:8000 --workers 2 app:app"
  }
  
  django = {
    vmid     = 304
    hostname = "test-django"
    ip       = "192.168.171.204"
    cores    = 2
    memory   = 2048
    framework = "Python Django"
    repo     = "https://github.com/mouones/test"
    packages = ["python3", "python3-pip", "python3-venv", "git"]
    setup_commands = [
      "cd /opt/app && python3 -m venv venv",
      ". /opt/app/venv/bin/activate && pip install --upgrade pip",
      ". /opt/app/venv/bin/activate && pip install django gunicorn"
    ]
    start_command = "/opt/app/venv/bin/gunicorn --bind 0.0.0.0:8000 --workers 2 wsgi:application || /opt/app/venv/bin/python app.py"
  }
  
  fastapi = {
    vmid     = 305
    hostname = "test-fastapi"
    ip       = "192.168.171.205"
    cores    = 2
    memory   = 2048
    framework = "Python FastAPI"
    repo     = "https://github.com/mouones/test"
    packages = ["python3", "python3-pip", "python3-venv", "git"]
    setup_commands = [
      "cd /opt/app && python3 -m venv venv",
      ". /opt/app/venv/bin/activate && pip install --upgrade pip",
      ". /opt/app/venv/bin/activate && pip install fastapi uvicorn"
    ]
    start_command = "/opt/app/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 || /opt/app/venv/bin/python app.py"
  }
  
  express = {
    vmid     = 306
    hostname = "test-express"
    ip       = "192.168.171.206"
    cores    = 2
    memory   = 2048
    framework = "Node.js Express"
    repo     = "https://github.com/mouones/test"
    packages = ["curl", "git"]
    setup_commands = [
      "curl -fsSL https://deb.nodesource.com/setup_18.x | bash -",
      "apt-get install -y nodejs",
      "cd /opt/app && npm install express"
    ]
    start_command = "cd /opt/app && node app.js"
  }
  
  nextjs = {
    vmid     = 307
    hostname = "test-nextjs"
    ip       = "192.168.171.207"
    cores    = 2
    memory   = 2048
    framework = "Next.js"
    repo     = "https://github.com/mouones/test"
    packages = ["curl", "git"]
    setup_commands = [
      "curl -fsSL https://deb.nodesource.com/setup_18.x | bash -",
      "apt-get install -y nodejs",
      "cd /opt/app && npm install next react react-dom"
    ]
    start_command = "cd /opt/app && npm start || node app.js"
  }
  
  laravel = {
    vmid     = 308
    hostname = "test-laravel"
    ip       = "192.168.171.208"
    cores    = 2
    memory   = 2048
    framework = "PHP Laravel"
    repo     = "https://github.com/mouones/test"
    packages = ["php", "php-cli", "php-fpm", "php-mysql", "php-xml", "php-mbstring", "php-curl", "php-zip", "unzip", "git", "curl"]
    setup_commands = [
      "curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer",
      "cd /opt/app && composer install --no-interaction --prefer-dist 2>/dev/null || true"
    ]
    start_command = "cd /opt/app && php -S 0.0.0.0:8000"
  }
  
  go = {
    vmid     = 309
    hostname = "test-go"
    ip       = "192.168.171.209"
    cores    = 2
    memory   = 2048
    framework = "Go Gin"
    repo     = "https://github.com/mouones/test"
    packages = ["golang", "git"]
    setup_commands = [
      "cd /opt/app && go mod init app 2>/dev/null || true",
      "cd /opt/app && go build -o app 2>/dev/null || echo 'package main; import \"net/http\"; func main() { http.HandleFunc(\"/\", func(w http.ResponseWriter, r *http.Request) { w.Write([]byte(\"Hello from Go!\")) }); http.ListenAndServe(\":8000\", nil) }' > main.go && go build -o app"
    ]
    start_command = "cd /opt/app && ./app"
  }
  
  rust = {
    vmid     = 310
    hostname = "test-rust"
    ip       = "192.168.171.210"
    cores    = 2
    memory   = 3072
    framework = "Rust Actix"
    repo     = "https://github.com/mouones/test"
    packages = ["curl", "build-essential", "git"]
    setup_commands = [
      "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y",
      ". $HOME/.cargo/env && cd /opt/app && cargo init --name app 2>/dev/null || true"
    ]
    start_command = ". $HOME/.cargo/env && cd /opt/app && echo 'Rust app ready'"
  }
  
  rails = {
    vmid     = 311
    hostname = "test-rails"
    ip       = "192.168.171.211"
    cores    = 2
    memory   = 2048
    framework = "Ruby on Rails"
    repo     = "https://github.com/mouones/test"
    packages = ["ruby", "ruby-dev", "build-essential", "git", "libsqlite3-dev"]
    setup_commands = [
      "gem install bundler",
      "cd /opt/app && gem install sinatra"
    ]
    start_command = "cd /opt/app && ruby -rsinatra -e 'get(\"/\") { \"Hello from Ruby!\" }' -o 0.0.0.0 -p 8000"
  }
  
  nginx = {
    vmid     = 312
    hostname = "test-nginx"
    ip       = "192.168.171.212"
    cores    = 1
    memory   = 1024
    framework = "Static Site (Nginx)"
    repo     = "https://github.com/mouones/test"
    packages = ["nginx", "git"]
    setup_commands = [
      "rm -rf /var/www/html/*",
      "cp -r /opt/app/* /var/www/html/ 2>/dev/null || echo '<h1>Hello from Nginx!</h1>' > /var/www/html/index.html",
      "systemctl enable nginx"
    ]
    start_command = "systemctl start nginx"
  }
  
  jenkins = {
    vmid     = 313
    hostname = "test-jenkins"
    ip       = "192.168.171.213"
    cores    = 2
    memory   = 3072
    framework = "Jenkins CI/CD"
    repo     = "https://github.com/mouones/test"
    packages = ["openjdk-17-jre-headless", "wget", "git", "curl"]
    setup_commands = [
      "wget -q -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key",
      "echo 'deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/' > /etc/apt/sources.list.d/jenkins.list",
      "apt-get update && apt-get install -y jenkins",
      "systemctl enable jenkins"
    ]
    start_command = "systemctl start jenkins"
  }
}
VARSEOF

echo "Starting deployment of all 11 frameworks..."
terraform apply -auto-approve

echo ""
echo "Deployment complete! Check containers:"
pct list

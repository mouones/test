# Auto-loaded framework configurations for all 10 frameworks

containers = {
  # Python Frameworks
  flask = {
    vmid           = 303
    hostname       = "test-flask"
    ip             = "192.168.171.203"
    cores          = 2
    memory         = 2048
    swap           = 512
    disk_size      = "8G"
    framework      = "Python Flask"
    repo           = "https://github.com/mouones/test"
    packages       = ["python3", "python3-pip", "python3-venv", "git"]
    setup_commands = [
      "cd /opt/app && python3 -m venv venv",
      ". /opt/app/venv/bin/activate && pip install --upgrade pip",
      ". /opt/app/venv/bin/activate && pip install flask gunicorn"
    ]
    build_command = ". venv/bin/activate && (pip install -r requirements.txt || pip install flask gunicorn)"
    start_command = "/opt/app/venv/bin/gunicorn --bind 0.0.0.0:8000 --workers 2 --timeout 120 app:app"
    port          = 8000
  }

  django = {
    vmid           = 304
    hostname       = "test-django"
    ip             = "192.168.171.204"
    cores          = 2
    memory         = 2048
    swap           = 512
    disk_size      = "8G"
    framework      = "Python Django"
    repo           = "https://github.com/mouones/test"
    packages       = ["python3", "python3-pip", "python3-venv", "git"]
    setup_commands = [
      "cd /opt/app && python3 -m venv venv",
      ". /opt/app/venv/bin/activate && pip install --upgrade pip",
      ". /opt/app/venv/bin/activate && pip install django gunicorn"
    ]
    build_command = ". venv/bin/activate && (pip install -r requirements.txt || pip install django gunicorn) && (python manage.py migrate --noinput || true)"
    start_command = "/opt/app/venv/bin/gunicorn --bind 0.0.0.0:8000 --workers 2 wsgi:application || /opt/app/venv/bin/python app.py"
    port          = 8000
  }

  fastapi = {
    vmid           = 305
    hostname       = "test-fastapi"
    ip             = "192.168.171.205"
    cores          = 2
    memory         = 2048
    swap           = 512
    disk_size      = "8G"
    framework      = "Python FastAPI"
    repo           = "https://github.com/mouones/test"
    packages       = ["python3", "python3-pip", "python3-venv", "git"]
    setup_commands = [
      "cd /opt/app && python3 -m venv venv",
      ". /opt/app/venv/bin/activate && pip install --upgrade pip",
      ". /opt/app/venv/bin/activate && pip install fastapi uvicorn"
    ]
    build_command = ". venv/bin/activate && (pip install -r requirements.txt || pip install fastapi uvicorn)"
    start_command = "/opt/app/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 || /opt/app/venv/bin/python app.py"
    port          = 8000
  }

  # Node.js Frameworks
  express = {
    vmid           = 306
    hostname       = "test-express"
    ip             = "192.168.171.206"
    cores          = 2
    memory         = 2048
    swap           = 512
    disk_size      = "8G"
    framework      = "Node.js Express"
    repo           = "https://github.com/mouones/test"
    packages       = ["curl", "git"]
    setup_commands = [
      "curl -fsSL https://deb.nodesource.com/setup_18.x | bash -",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs"
    ]
    build_command = "(npm install --production || (echo '{\"name\":\"test\",\"version\":\"1.0.0\",\"dependencies\":{\"express\":\"^4.18.0\"}}' > package.json && npm install))"
    start_command = "cd /opt/app && (node app.js || node server.js || node index.js)"
    port          = 3000
  }

  nextjs = {
    vmid           = 307
    hostname       = "test-nextjs"
    ip             = "192.168.171.207"
    cores          = 2
    memory         = 2048
    swap           = 512
    disk_size      = "8G"
    framework      = "Next.js"
    repo           = "https://github.com/mouones/test"
    packages       = ["curl", "git"]
    setup_commands = [
      "curl -fsSL https://deb.nodesource.com/setup_18.x | bash -",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs"
    ]
    build_command = "(npm install && npm run build) || (npm install express && echo '{\"name\":\"test\"}' > package.json)"
    start_command = "cd /opt/app && (npm start || node app.js)"
    port          = 3000
  }

  # PHP Framework
  laravel = {
    vmid           = 308
    hostname       = "test-laravel"
    ip             = "192.168.171.208"
    cores          = 2
    memory         = 2048
    swap           = 512
    disk_size      = "8G"
    framework      = "PHP Laravel"
    repo           = "https://github.com/mouones/test"
    packages       = ["php", "php-cli", "php-fpm", "php-mysql", "php-xml", "php-mbstring", "php-curl", "php-zip", "unzip", "git", "curl"]
    setup_commands = [
      "curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer",
      "cd /opt/app && (composer install --no-interaction --prefer-dist || true)",
      "cd /opt/app && (cp .env.example .env || echo 'APP_KEY=' > .env)",
      "cd /opt/app && (php artisan key:generate --no-interaction || true)"
    ]
    build_command = "true"
    start_command = "cd /opt/app && (php artisan serve --host=0.0.0.0 --port=8000 || php -S 0.0.0.0:8000 -t public)"
    port          = 8000
  }

  # Go Framework
  go = {
    vmid           = 309
    hostname       = "test-go"
    ip             = "192.168.171.209"
    cores          = 2
    memory         = 2048
    swap           = 512
    disk_size      = "8G"
    framework      = "Go Gin"
    repo           = "https://github.com/mouones/test"
    packages       = ["golang", "git"]
    setup_commands = [
      "cd /opt/app && (go mod download || go get -u github.com/gin-gonic/gin || true)"
    ]
    build_command = "(go build -o app . || go build -o app main.go)"
    start_command = "cd /opt/app && (./app || go run main.go || go run app.go)"
    port          = 8080
  }

  # Rust Framework
  rust = {
    vmid           = 310
    hostname       = "test-rust"
    ip             = "192.168.171.210"
    cores          = 2
    memory         = 2048
    swap           = 512
    disk_size      = "8G"
    framework      = "Rust Actix"
    repo           = "https://github.com/mouones/test"
    packages       = ["curl", "git", "build-essential"]
    setup_commands = [
      "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y",
      "cd /opt/app && /root/.cargo/bin/cargo fetch || true"
    ]
    build_command = "/root/.cargo/bin/cargo build --release || /root/.cargo/bin/cargo build"
    start_command = "cd /opt/app && (/root/.cargo/bin/cargo run --release || /root/.cargo/bin/cargo run || ./target/release/app)"
    port          = 8080
  }

  # Ruby Framework
  ruby = {
    vmid           = 311
    hostname       = "test-ruby"
    ip             = "192.168.171.211"
    cores          = 2
    memory         = 2048
    swap           = 512
    disk_size      = "8G"
    framework      = "Ruby on Rails"
    repo           = "https://github.com/mouones/test"
    packages       = ["ruby", "ruby-dev", "git", "build-essential", "libsqlite3-dev"]
    setup_commands = [
      "gem install bundler",
      "cd /opt/app && (bundle install || gem install rails)"
    ]
    build_command = "(bundle install || gem install rails)"
    start_command = "cd /opt/app && (bundle exec rails server -b 0.0.0.0 || ruby app.rb)"
    port          = 3000
  }

  # Static Site
  nginx = {
    vmid           = 312
    hostname       = "test-static"
    ip             = "192.168.171.212"
    cores          = 1
    memory         = 1024
    swap           = 256
    disk_size      = "4G"
    framework      = "Static Site (Nginx)"
    repo           = "https://github.com/mouones/test"
    packages       = ["nginx", "git"]
    setup_commands = [
      "rm -f /etc/nginx/sites-enabled/default",
      "echo 'server { listen 80; root /opt/app; index index.html index.htm; location / { try_files \\$uri \\$uri/ =404; } }' > /etc/nginx/sites-available/app",
      "ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app"
    ]
    build_command = "true"
    start_command = "nginx -g 'daemon off;'"
    port          = 80
  }
}

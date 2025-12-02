#!/usr/bin/env python3
from flask import Flask, request, jsonify, render_template, send_from_directory
import subprocess
import time
import os

app = Flask(__name__)

# LXC Configuration
TEMPLATE = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
CT_RANGE_START = 300
BASE_IP = "192.168.171."
IP_START = 200
GATEWAY = "192.168.171.2"
NETMASK = "24"
PASSWORD = "rootpass123"

# Framework configurations
FRAMEWORKS = {
    'python-flask': {
        'name': 'Python Flask',
        'port': 8000,
        'install': 'apt-get update && apt-get install -y python3 python3-pip python3-venv git',
        'setup': '''cd /opt/app && python3 -m venv venv && . venv/bin/activate && 
                    pip install --upgrade pip && 
                    if [ -f requirements.txt ]; then pip install -r requirements.txt; else pip install flask; fi''',
        'run_cmd': '/opt/app/venv/bin/python app.py',
        'entry_file': 'app.py'
    },
    'python-django': {
        'name': 'Python Django',
        'port': 8000,
        'install': 'apt-get update && apt-get install -y python3 python3-pip python3-venv git',
        'setup': '''cd /opt/app && python3 -m venv venv && . venv/bin/activate && 
                    pip install --upgrade pip && 
                    if [ -f requirements.txt ]; then pip install -r requirements.txt; else pip install django gunicorn; fi && 
                    if [ -f manage.py ]; then python manage.py migrate; fi''',
        'run_cmd': '/opt/app/venv/bin/gunicorn --bind 0.0.0.0:8000 --workers 3 --timeout 120 $(basename $(find . -name wsgi.py -not -path "*/venv/*") .py | sed "s|/|.|g"):application',
        'entry_file': 'manage.py'
    },
    'python-fastapi': {
        'name': 'Python FastAPI',
        'port': 8000,
        'install': 'apt-get update && apt-get install -y python3 python3-pip python3-venv git',
        'setup': '''cd /opt/app && python3 -m venv venv && . venv/bin/activate && 
                    pip install --upgrade pip && 
                    if [ -f requirements.txt ]; then pip install -r requirements.txt; else pip install fastapi uvicorn; fi''',
        'run_cmd': '/opt/app/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000',
        'entry_file': 'main.py'
    },
    'nodejs-express': {
        'name': 'Node.js Express',
        'port': 3000,
        'install': 'apt-get update && apt-get install -y curl git && curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && apt-get install -y nodejs',
        'setup': 'cd /opt/app && npm install',
        'run_cmd': 'node app.js',
        'entry_file': 'app.js'
    },
    'nodejs-nextjs': {
        'name': 'Next.js',
        'port': 3000,
        'install': 'apt-get update && apt-get install -y curl git && curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && apt-get install -y nodejs',
        'setup': 'cd /opt/app && npm install && npm run build',
        'run_cmd': 'npm start',
        'entry_file': 'package.json'
    },
    'php-laravel': {
        'name': 'PHP Laravel',
        'port': 8000,
        'install': 'apt-get update && apt-get install -y php php-cli php-fpm php-mysql php-xml php-mbstring php-curl php-zip unzip git curl && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer',
        'setup': '''cd /opt/app && composer install && 
                    if [ ! -f .env ]; then cp .env.example .env 2>/dev/null || echo "APP_KEY=" > .env; fi && 
                    php artisan key:generate 2>/dev/null || true''',
        'run_cmd': 'php artisan serve --host=0.0.0.0 --port=8000',
        'entry_file': 'artisan'
    },
    'go-gin': {
        'name': 'Go Gin',
        'port': 8080,
        'install': 'apt-get update && apt-get install -y golang git',
        'setup': 'cd /opt/app && go mod download && go build -o app',
        'run_cmd': './app',
        'entry_file': 'main.go'
    },
    'rust-actix': {
        'name': 'Rust Actix',
        'port': 8080,
        'install': 'apt-get update && apt-get install -y curl build-essential git && curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && . $HOME/.cargo/env',
        'setup': 'cd /opt/app && . $HOME/.cargo/env && cargo build --release',
        'run_cmd': '. $HOME/.cargo/env && ./target/release/$(grep "^name" Cargo.toml | cut -d\\" -f2 | head -n1)',
        'entry_file': 'Cargo.toml'
    },
    'ruby-rails': {
        'name': 'Ruby on Rails',
        'port': 3000,
        'install': 'apt-get update && apt-get install -y ruby ruby-dev build-essential git libsqlite3-dev && gem install bundler',
        'setup': '''cd /opt/app && bundle install && 
                    if [ -f bin/rails ]; then bundle exec rails db:create db:migrate 2>/dev/null || true; fi''',
        'run_cmd': 'bundle exec rails server -b 0.0.0.0',
        'entry_file': 'Gemfile'
    },
    'static-nginx': {
        'name': 'Static Site (Nginx)',
        'port': 80,
        'install': 'apt-get update && apt-get install -y nginx git',
        'setup': '''rm -rf /var/www/html/* && 
                    if [ -d /opt/app/dist ]; then cp -r /opt/app/dist/* /var/www/html/; 
                    elif [ -d /opt/app/build ]; then cp -r /opt/app/build/* /var/www/html/; 
                    elif [ -d /opt/app/public ]; then cp -r /opt/app/public/* /var/www/html/; 
                    else cp -r /opt/app/* /var/www/html/; fi && 
                    systemctl enable nginx''',
        'run_cmd': 'systemctl start nginx',
        'entry_file': 'index.html'
    }
}

def run_cmd(cmd):
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout.strip(), result.returncode

def get_next_ctid():
    """Find next available container ID"""
    used = set()
    output, _ = run_cmd("pct list | awk 'NR>1{print $1}'")
    if output:
        used.update(int(x) for x in output.split('\n') if x and x.isdigit())
    for ctid in range(CT_RANGE_START, CT_RANGE_START + 100):
        if ctid not in used:
            return ctid
    return None

def get_static_ip(ctid):
    """Calculate static IP based on container ID"""
    offset = ctid - CT_RANGE_START
    return f"{BASE_IP}{IP_START + offset}"

@app.route('/')
def index():
    """Serve web interface"""
    return render_template('index.html')

@app.route('/frameworks', methods=['GET'])
def get_frameworks():
    """Return available frameworks"""
    return jsonify({
        'frameworks': {k: {'name': v['name'], 'port': v['port']} for k, v in FRAMEWORKS.items()}
    })

@app.route('/deploy', methods=['POST'])
def deploy():
    """Deploy a new LXC container with the application"""
    data = request.json
    app_name = data.get('name', 'app')
    framework = data.get('framework', 'python-flask')
    repo = data.get('repo')
    deploy_type = data.get('type', 'lxc')

    if not repo:
        return jsonify({'error': 'repo required'}), 400

    if framework not in FRAMEWORKS:
        return jsonify({'error': f'Unknown framework: {framework}. Available: {list(FRAMEWORKS.keys())}'}), 400

    fw_config = FRAMEWORKS[framework]

    # Get next container ID
    ctid = get_next_ctid()
    if not ctid:
        return jsonify({'error': 'No container ID available'}), 500

    ip = get_static_ip(ctid)

    try:
        # Create container
        run_cmd(f"""pct create {ctid} {TEMPLATE} \
            --hostname {app_name} \
            --memory 2048 \
            --cores 2 \
            --net0 name=eth0,bridge=vmbr0,ip={ip}/{NETMASK},gw={GATEWAY} \
            --password {PASSWORD} \
            --features nesting=1 \
            --unprivileged 1 \
            --rootfs local-lvm:8 \
            --onboot 1""")

        # Start container
        run_cmd(f"pct start {ctid}")
        
        # Wait for container to be ready
        time.sleep(15)

        # Install framework dependencies
        print(f"Installing {fw_config['name']}...")
        run_cmd(f"pct exec {ctid} -- bash -c '{fw_config['install']}'")

        # Clone repository
        print(f"Cloning repository: {repo}")
        run_cmd(f"pct exec {ctid} -- bash -c 'cd /opt && git clone {repo} app'")

        # Setup application
        print(f"Setting up application...")
        run_cmd(f"pct exec {ctid} -- bash -c '{fw_config['setup']}'")

        # Create systemd service
        service_content = f"""[Unit]
Description={app_name} Application ({fw_config['name']})
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/app
Environment="PATH=/opt/app/venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart={fw_config['run_cmd']}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
"""
        
        run_cmd(f"pct exec {ctid} -- bash -c 'cat > /etc/systemd/system/{app_name}.service' <<'EOF'\n{service_content}\nEOF")
        run_cmd(f"pct exec {ctid} -- systemctl daemon-reload")
        run_cmd(f"pct exec {ctid} -- systemctl enable {app_name}")
        run_cmd(f"pct exec {ctid} -- systemctl start {app_name}")

        return jsonify({
            'status': 'success',
            'ctid': ctid,
            'name': app_name,
            'ip': ip,
            'framework': framework,
            'framework_name': fw_config['name'],
            'repo': repo,
            'port': fw_config['port'],
            'url': f'http://{ip}:{fw_config["port"]}',
            'ssh': f'pct enter {ctid}',
            'password': PASSWORD
        })

    except Exception as e:
        # Cleanup on failure
        run_cmd(f"pct stop {ctid}")
        run_cmd(f"pct destroy {ctid}")
        return jsonify({'error': str(e)}), 500

@app.route('/list', methods=['GET'])
def list_containers():
    """List all containers"""
    output, _ = run_cmd("pct list")
    return jsonify({'containers': output})

@app.route('/delete/<int:ctid>', methods=['DELETE'])
def delete_container(ctid):
    """Delete a container"""
    run_cmd(f"pct stop {ctid}")
    run_cmd(f"pct destroy {ctid}")
    return jsonify({'status': 'deleted', 'ctid': ctid})

@app.route('/status/<int:ctid>', methods=['GET'])
def status_container(ctid):
    """Get container status"""
    output, _ = run_cmd(f"pct status {ctid}")
    return jsonify({'ctid': ctid, 'status': output})

@app.route('/logs/<int:ctid>', methods=['GET'])
def get_logs(ctid):
    """Get container application logs"""
    # Get service name from container
    output, _ = run_cmd(f"pct exec {ctid} -- systemctl list-units --type=service --all | grep -v 'systemd\\|dbus\\|rsyslog' | head -n 5")
    return jsonify({'ctid': ctid, 'logs': output})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)

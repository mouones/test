#!/usr/bin/env python3
"""
Enhanced PaaS API with Storage Optimization and Conflict Prevention
Supports 10+ frameworks with automatic test repository creation
"""

from flask import Flask, request, jsonify, render_template
import subprocess
import time
import os
import json

app = Flask(__name__)

# Configuration
TEMPLATE = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
CT_RANGE_START = 300
CT_RANGE_END = 399
BASE_IP = "192.168.171."
IP_START = 200
GATEWAY = "192.168.171.2"
NETMASK = "24"
PASSWORD = "thenoob123."

# Framework configurations with test repos
FRAMEWORKS = {
    'python-flask': {
        'name': 'Python Flask',
        'port': 8000,
        'test_repo': 'https://github.com/mouones/test',
        'install': 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip python3-venv git',
        'setup': '''cd /opt/app && python3 -m venv venv && . venv/bin/activate && 
                    pip install --upgrade pip && 
                    if [ -f requirements.txt ]; then pip install -r requirements.txt; else pip install flask gunicorn; fi''',
        'run_cmd': '/opt/app/venv/bin/gunicorn --bind 0.0.0.0:8000 --workers 2 --timeout 120 app:app',
        'entry_file': 'app.py'
    },
    'python-django': {
        'name': 'Python Django',
        'port': 8000,
        'test_repo': 'https://github.com/mouones/test',  # Will work with any Python app
        'install': 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip python3-venv git',
        'setup': '''cd /opt/app && python3 -m venv venv && . venv/bin/activate && 
                    pip install --upgrade pip && 
                    if [ -f requirements.txt ]; then pip install -r requirements.txt; else pip install django gunicorn; fi && 
                    if [ -f manage.py ]; then python manage.py migrate --noinput 2>/dev/null || true; fi''',
        'run_cmd': '/opt/app/venv/bin/gunicorn --bind 0.0.0.0:8000 --workers 2 --timeout 120 wsgi:application || /opt/app/venv/bin/python app.py',
        'entry_file': 'manage.py'
    },
    'python-fastapi': {
        'name': 'Python FastAPI',
        'port': 8000,
        'test_repo': 'https://github.com/mouones/test',
        'install': 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip python3-venv git',
        'setup': '''cd /opt/app && python3 -m venv venv && . venv/bin/activate && 
                    pip install --upgrade pip && 
                    if [ -f requirements.txt ]; then pip install -r requirements.txt; else pip install fastapi uvicorn; fi''',
        'run_cmd': '/opt/app/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 || /opt/app/venv/bin/python app.py',
        'entry_file': 'main.py'
    },
    'nodejs-express': {
        'name': 'Node.js Express',
        'port': 3000,
        'test_repo': 'https://github.com/mouones/test',
        'install': 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y curl git && curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && apt-get install -y nodejs',
        'setup': '''cd /opt/app && 
                    if [ -f package.json ]; then npm install --production; 
                    else echo '{"name":"test-app","version":"1.0.0","main":"app.js","dependencies":{"express":"^4.18.0"}}' > package.json && npm install; fi''',
        'run_cmd': 'cd /opt/app && node app.js || node server.js || node index.js',
        'entry_file': 'app.js'
    },
    'nodejs-nextjs': {
        'name': 'Next.js',
        'port': 3000,
        'test_repo': 'https://github.com/mouones/test',
        'install': 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y curl git && curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && apt-get install -y nodejs',
        'setup': '''cd /opt/app && 
                    if [ -f package.json ]; then npm install && npm run build 2>/dev/null || true; 
                    else npm install express && echo '{"name":"test-app","version":"1.0.0"}' > package.json; fi''',
        'run_cmd': 'cd /opt/app && npm start || node app.js',
        'entry_file': 'package.json'
    },
    'php-laravel': {
        'name': 'PHP Laravel',
        'port': 8000,
        'test_repo': 'https://github.com/mouones/test',
        'install': '''apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y php php-cli php-fpm php-mysql php-xml php-mbstring php-curl php-zip unzip git curl && 
                     curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer''',
        'setup': '''cd /opt/app && 
                    if [ -f composer.json ]; then composer install --no-interaction --prefer-dist; fi && 
                    if [ ! -f .env ]; then cp .env.example .env 2>/dev/null || echo "APP_KEY=" > .env; fi && 
                    if [ -f artisan ]; then php artisan key:generate --no-interaction 2>/dev/null || true; fi''',
        'run_cmd': 'cd /opt/app && php artisan serve --host=0.0.0.0 --port=8000 || php -S 0.0.0.0:8000 -t public',
        'entry_file': 'artisan'
    },
    'go-gin': {
        'name': 'Go Gin',
        'port': 8080,
        'test_repo': 'https://github.com/mouones/test',
        'install': 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y golang git',
        'setup': '''cd /opt/app && 
                    if [ -f go.mod ]; then go mod download && go build -o app; 
                    else echo 'package main; import "fmt"; import "net/http"; func main() { http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) { fmt.Fprintf(w, "Hello from Go!") }); http.ListenAndServe(":8080", nil) }' > main.go && go mod init app && go build -o app; fi''',
        'run_cmd': 'cd /opt/app && ./app',
        'entry_file': 'main.go'
    },
    'rust-actix': {
        'name': 'Rust Actix',
        'port': 8080,
        'test_repo': 'https://github.com/mouones/test',
        'install': 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y curl build-essential git && curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y',
        'setup': '''cd /opt/app && . $HOME/.cargo/env && 
                    if [ -f Cargo.toml ]; then cargo build --release; 
                    else mkdir -p src && echo 'fn main() { println!("Hello from Rust!"); }' > src/main.rs && cargo init --name app && cargo build --release; fi''',
        'run_cmd': '. $HOME/.cargo/env && cd /opt/app && ./target/release/app || echo "Rust app placeholder"',
        'entry_file': 'Cargo.toml'
    },
    'ruby-rails': {
        'name': 'Ruby on Rails',
        'port': 3000,
        'test_repo': 'https://github.com/mouones/test',
        'install': 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y ruby ruby-dev build-essential git libsqlite3-dev && gem install bundler',
        'setup': '''cd /opt/app && 
                    if [ -f Gemfile ]; then bundle install; 
                    if [ -f bin/rails ]; then bundle exec rails db:create db:migrate 2>/dev/null || true; fi; 
                    else gem install sinatra && echo "require 'sinatra'; get('/') { 'Hello from Ruby!' }" > app.rb; fi''',
        'run_cmd': 'cd /opt/app && bundle exec rails server -b 0.0.0.0 || ruby app.rb -o 0.0.0.0',
        'entry_file': 'Gemfile'
    },
    'static-nginx': {
        'name': 'Static Site (Nginx)',
        'port': 80,
        'test_repo': 'https://github.com/mouones/test',
        'install': 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y nginx git',
        'setup': '''rm -rf /var/www/html/* && 
                    if [ -d /opt/app/dist ]; then cp -r /opt/app/dist/* /var/www/html/; 
                    elif [ -d /opt/app/build ]; then cp -r /opt/app/build/* /var/www/html/; 
                    elif [ -d /opt/app/public ]; then cp -r /opt/app/public/* /var/www/html/; 
                    else cp -r /opt/app/* /var/www/html/ 2>/dev/null || echo "<h1>Static Site</h1>" > /var/www/html/index.html; fi && 
                    systemctl enable nginx''',
        'run_cmd': 'systemctl start nginx && systemctl status nginx',
        'entry_file': 'index.html'
    },
    'jenkins': {
        'name': 'Jenkins CI/CD',
        'port': 8080,
        'test_repo': 'https://github.com/mouones/test',
        'install': '''apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-17-jre-headless wget git curl && 
                     wget -q -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key && 
                     echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list && 
                     apt-get update && apt-get install -y jenkins''',
        'setup': 'systemctl enable jenkins && systemctl start jenkins && sleep 10',
        'run_cmd': 'systemctl start jenkins && systemctl status jenkins',
        'entry_file': 'jenkins'
    }
}

def run_cmd(cmd):
    """Execute shell command and return output"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=300)
        return result.stdout.strip(), result.returncode
    except subprocess.TimeoutExpired:
        return "Command timed out", 1
    except Exception as e:
        return str(e), 1

def get_used_ids():
    """Get all used container and VM IDs"""
    used = set()
    
    # Get container IDs
    output, _ = run_cmd("pct list | awk 'NR>1{print $1}'")
    if output:
        used.update(int(x) for x in output.split('\n') if x and x.isdigit())
    
    # Get VM IDs
    output, _ = run_cmd("qm list | awk 'NR>1{print $1}'")
    if output:
        used.update(int(x) for x in output.split('\n') if x and x.isdigit())
    
    return used

def get_used_ips():
    """Get all used IP addresses"""
    used_ips = set()
    
    # Check containers
    output, _ = run_cmd("pct list | awk 'NR>1{print $1}'")
    if output:
        for ctid in output.split('\n'):
            if ctid and ctid.isdigit():
                ip_output, _ = run_cmd(f"pct config {ctid} | grep 'ip=' | grep -oP '\\d+\\.\\d+\\.\\d+\\.\\d+'")
                if ip_output:
                    used_ips.add(ip_output.strip())
    
    return used_ips

def get_next_ctid():
    """Find next available container ID without conflicts"""
    used = get_used_ids()
    for ctid in range(CT_RANGE_START, CT_RANGE_END + 1):
        if ctid not in used:
            return ctid
    return None

def get_static_ip(ctid):
    """Calculate static IP and ensure no conflicts"""
    offset = ctid - CT_RANGE_START
    candidate_ip = f"{BASE_IP}{IP_START + offset}"
    
    used_ips = get_used_ips()
    
    # If calculated IP is used, find next available
    if candidate_ip in used_ips:
        for i in range(IP_START, IP_START + 100):
            test_ip = f"{BASE_IP}{i}"
            if test_ip not in used_ips:
                return test_ip
    
    return candidate_ip

@app.route('/')
def index():
    """Serve web interface"""
    return render_template('index.html')

@app.route('/frameworks', methods=['GET'])
def get_frameworks():
    """Return available frameworks with test repos"""
    return jsonify({
        'frameworks': {
            k: {
                'name': v['name'], 
                'port': v['port'],
                'test_repo': v.get('test_repo', '')
            } 
            for k, v in FRAMEWORKS.items()
        }
    })

@app.route('/deploy', methods=['POST'])
def deploy():
    """Deploy a new LXC container with conflict prevention"""
    data = request.json
    app_name = data.get('name', 'app').replace(' ', '-').lower()
    framework = data.get('framework', 'python-flask')
    repo = data.get('repo') or FRAMEWORKS.get(framework, {}).get('test_repo', '')
    deploy_type = data.get('type', 'lxc')
    memory = data.get('memory', 5120)  # Default 5GB in MB
    cores = data.get('cores', 2)  # Default 2 cores

    if not repo:
        return jsonify({'error': 'Repository URL required'}), 400

    if framework not in FRAMEWORKS:
        return jsonify({'error': f'Unknown framework: {framework}'}), 400

    fw_config = FRAMEWORKS[framework]

    # Get next available ID (checks both containers and VMs)
    ctid = get_next_ctid()
    if not ctid:
        return jsonify({'error': 'No container ID available in range 300-399'}), 500

    # Get IP without conflicts
    ip = get_static_ip(ctid)

    print(f"Deploying {app_name} with CTID {ctid}, IP {ip}, Memory {memory}MB, Cores {cores}")

    try:
        # Create container
        create_cmd = f"""pct create {ctid} {TEMPLATE} \
            --hostname {app_name} \
            --memory {memory} \
            --cores {cores} \
            --net0 name=eth0,bridge=vmbr0,ip={ip}/{NETMASK},gw={GATEWAY} \
            --password {PASSWORD} \
            --features nesting=1 \
            --unprivileged 1 \
            --rootfs local-lvm:8 \
            --onboot 1 \
            --description 'Framework: {framework}|Port: {fw_config["port"]}'"""
        
        output, code = run_cmd(create_cmd)
        if code != 0:
            return jsonify({'error': f'Failed to create container: {output}'}), 500

        # Start container
        run_cmd(f"pct start {ctid}")
        time.sleep(15)

        # Install framework
        print(f"Installing {fw_config['name']}...")
        output, code = run_cmd(f"pct exec {ctid} -- bash -c '{fw_config['install']}'")
        if code != 0:
            raise Exception(f"Installation failed: {output}")

        # Clone repository
        print(f"Cloning {repo}...")
        output, code = run_cmd(f"pct exec {ctid} -- bash -c 'cd /opt && git clone {repo} app 2>&1'")
        if code != 0:
            raise Exception(f"Git clone failed: {output}")

        # Setup application
        print(f"Setting up application...")
        output, code = run_cmd(f"pct exec {ctid} -- bash -c '{fw_config['setup']}'")

        # Create systemd service
        service_content = f"""[Unit]
Description={app_name} Application ({fw_config['name']})
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/app
Environment="PATH=/opt/app/venv/bin:/root/.cargo/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/bin/bash -c '{fw_config['run_cmd']}'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
"""
        
        # Write service file
        run_cmd(f"pct exec {ctid} -- bash -c 'cat > /etc/systemd/system/{app_name}.service <<\"EOFSERVICE\"\n{service_content}\nEOFSERVICE'")
        run_cmd(f"pct exec {ctid} -- systemctl daemon-reload")
        run_cmd(f"pct exec {ctid} -- systemctl enable {app_name}")
        run_cmd(f"pct exec {ctid} -- systemctl start {app_name}")

        # Wait a moment for service to start
        time.sleep(5)

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
            'password': PASSWORD,
            'message': f'Deployed successfully! Access at http://{ip}:{fw_config["port"]}'
        })

    except Exception as e:
        # Cleanup on failure
        print(f"Deployment failed: {str(e)}")
        run_cmd(f"pct stop {ctid} 2>/dev/null || true")
        run_cmd(f"pct destroy {ctid} 2>/dev/null || true")
        return jsonify({'error': str(e)}), 500

@app.route('/list', methods=['GET'])
def list_containers():
    """List all containers with details including status and IPs"""
    containers = []
    output, _ = run_cmd("pct list | awk 'NR>1{print $1}'")
    
    if output:
        for ctid in output.split('\n'):
            if ctid and ctid.isdigit():
                # Get container details
                status_output, _ = run_cmd(f"pct status {ctid}")
                config_output, _ = run_cmd(f"pct config {ctid}")
                
                # Parse hostname, IP, and port from description
                hostname = "unknown"
                ip = "unknown"
                port = 8000  # Default port
                framework = "unknown"
                
                for line in config_output.split('\n'):
                    if line.startswith('hostname:'):
                        hostname = line.split(':', 1)[1].strip()
                    elif 'ip=' in line:
                        try:
                            ip = line.split('ip=')[1].split('/')[0].split(',')[0]
                        except:
                            pass
                    elif line.startswith('description:'):
                        desc = line.split(':', 1)[1].strip()
                        if 'Port:' in desc:
                            try:
                                port = int(desc.split('Port:')[1].split('|')[0].strip())
                            except:
                                pass
                        if 'Framework:' in desc:
                            try:
                                framework = desc.split('Framework:')[1].split('|')[0].strip()
                            except:
                                pass
                
                containers.append({
                    'ctid': int(ctid),
                    'hostname': hostname,
                    'status': status_output.replace('status: ', ''),
                    'ip': ip,
                    'port': port,
                    'framework': framework
                })
    
    return jsonify({'containers': containers})

@app.route('/delete/<int:ctid>', methods=['DELETE'])
def delete_container(ctid):
    """Delete a container"""
    run_cmd(f"pct stop {ctid} 2>/dev/null || true")
    time.sleep(2)
    run_cmd(f"pct destroy {ctid}")
    return jsonify({'status': 'deleted', 'ctid': ctid})

@app.route('/status/<int:ctid>', methods=['GET'])
def status_container(ctid):
    """Get container status"""
    output, _ = run_cmd(f"pct status {ctid}")
    return jsonify({'ctid': ctid, 'status': output})

@app.route('/terraform/deploy', methods=['POST'])
def terraform_deploy():
    """Deploy all 10 frameworks using Terraform"""
    import time
    start_time = time.time()
    
    try:
        # Upload Terraform config if not exists
        tf_dir = "/root/terraform-deploy"
        run_cmd(f"mkdir -p {tf_dir}")
        
        # Check if Terraform is installed
        result = run_cmd("which terraform")
        if not result or "terraform" not in result.lower():
            return jsonify({
                'error': 'Terraform not installed on Proxmox server',
                'details': 'Run: bash /root/setup-terraform-proxmox.sh'
            }), 500
        
        # Initialize Terraform if needed
        if not os.path.exists(f"{tf_dir}/.terraform"):
            print("Initializing Terraform...")
            run_cmd(f"cd {tf_dir} && terraform init")
        
        # Run Terraform apply
        print("Running Terraform apply...")
        output = run_cmd(f"cd {tf_dir} && terraform apply -auto-approve 2>&1")
        
        duration = time.time() - start_time
        
        if output and ("error" in output.lower() or "failed" in output.lower()):
            return jsonify({
                'error': 'Terraform deployment failed',
                'details': output,
                'duration': f'{duration:.1f}s'
            }), 500
        
        return jsonify({
            'status': 'success',
            'message': 'All 10 frameworks deployed successfully with Terraform',
            'deployed': 10,
            'duration': f'{duration:.1f}s',
            'output': output[-2000:] if output else 'Deployment successful'  # Last 2000 chars
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'duration': f'{time.time() - start_time:.1f}s'
        }), 500

@app.route('/deploy-all-tests', methods=['POST'])
def deploy_all_tests():
    """Deploy test containers for all frameworks"""
    results = []
    
    for idx, (fw_key, fw_config) in enumerate(FRAMEWORKS.items()):
        try:
            app_name = f"test-{fw_key.replace('_', '-')}"
            ctid = get_next_ctid()
            if not ctid:
                results.append({'framework': fw_key, 'status': 'error', 'message': 'No ID available'})
                continue
            
            ip = get_static_ip(ctid)
            repo = fw_config.get('test_repo', 'https://github.com/mouones/test')
            
            # Deploy this framework
            deploy_data = {
                'name': app_name,
                'repo': repo,
                'framework': fw_key,
                'type': 'lxc'
            }
            
            result = deploy_container_internal(deploy_data)
            results.append({
                'framework': fw_key,
                'framework_name': fw_config['name'],
                'status': 'success' if 'ctid' in result else 'error',
                'ctid': result.get('ctid'),
                'ip': result.get('ip'),
                'port': result.get('port'),
                'url': result.get('url'),
                'message': result.get('message', result.get('error', ''))
            })
            
            # Wait between deployments
            time.sleep(5)
            
        except Exception as e:
            results.append({
                'framework': fw_key,
                'status': 'error',
                'message': str(e)
            })
    
    return jsonify({'results': results})

def deploy_container_internal(data):
    """Internal deployment function for batch operations"""
    app_name = data.get('name', 'app').replace(' ', '-').lower()
    framework = data.get('framework', 'python-flask')
    repo = data.get('repo') or FRAMEWORKS.get(framework, {}).get('test_repo', '')
    
    if not repo:
        return {'error': 'Repository URL required'}
    
    if framework not in FRAMEWORKS:
        return {'error': f'Unknown framework: {framework}'}
    
    fw_config = FRAMEWORKS[framework]
    
    # Get next available ID
    ctid = get_next_ctid()
    if not ctid:
        return {'error': 'No container ID available'}
    
    # Get IP without conflicts
    ip = get_static_ip(ctid)
    
    print(f"Deploying {app_name} with CTID {ctid} and IP {ip}")
    
    try:
        # Create container
        create_cmd = f"""pct create {ctid} {TEMPLATE} \
            --hostname {app_name} \
            --memory 5120 \
            --cores 2 \
            --net0 name=eth0,bridge=vmbr0,ip={ip}/{NETMASK},gw={GATEWAY} \
            --password {PASSWORD} \
            --features nesting=1 \
            --unprivileged 1 \
            --rootfs local-lvm:8 \
            --onboot 1"""
        
        output, code = run_cmd(create_cmd, timeout=60)
        if code != 0:
            return {'error': f'Failed to create container: {output}'}
        
        # Start container
        run_cmd(f"pct start {ctid}")
        time.sleep(15)
        
        # Install framework
        print(f"Installing {fw_config['name']}...")
        output, code = run_cmd(f"pct exec {ctid} -- bash -c '{fw_config['install']}'", timeout=300)
        if code != 0:
            raise Exception(f"Installation failed: {output}")
        
        # Clone repository
        print(f"Cloning {repo}...")
        output, code = run_cmd(f"pct exec {ctid} -- bash -c 'cd /opt && git clone {repo} app 2>&1'", timeout=120)
        if code != 0:
            raise Exception(f"Git clone failed: {output}")
        
        # Setup application
        print(f"Setting up application...")
        output, code = run_cmd(f"pct exec {ctid} -- bash -c '{fw_config['setup']}'", timeout=300)
        
        # Create systemd service
        service_content = f"""[Unit]
Description={app_name} Application ({fw_config['name']})
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/app
Environment="PATH=/opt/app/venv/bin:/root/.cargo/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/bin/bash -c '{fw_config['run_cmd']}'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
"""
        
        # Write service file
        run_cmd(f"pct exec {ctid} -- bash -c 'cat > /etc/systemd/system/{app_name}.service <<\"EOFSERVICE\"\n{service_content}\nEOFSERVICE'")
        run_cmd(f"pct exec {ctid} -- systemctl daemon-reload")
        run_cmd(f"pct exec {ctid} -- systemctl enable {app_name}")
        run_cmd(f"pct exec {ctid} -- systemctl start {app_name}")
        
        # Wait for service to start
        time.sleep(5)
        
        return {
            'status': 'success',
            'ctid': ctid,
            'name': app_name,
            'ip': ip,
            'framework': framework,
            'framework_name': fw_config['name'],
            'repo': repo,
            'port': fw_config['port'],
            'url': f'http://{ip}:{fw_config["port"]}',
            'message': f'Deployed successfully! Access at http://{ip}:{fw_config["port"]}'
        }
        
    except Exception as e:
        # Cleanup on failure
        print(f"Deployment failed: {str(e)}")
        run_cmd(f"pct stop {ctid} 2>/dev/null || true")
        run_cmd(f"pct destroy {ctid} 2>/dev/null || true")
        return {'error': str(e)}

if __name__ == '__main__':
    print("=" * 50)
    print("Proxmox PaaS Platform - Enhanced Edition")
    print("=" * 50)
    print(f"Supported frameworks: {len(FRAMEWORKS)}")
    print(f"Container ID range: {CT_RANGE_START}-{CT_RANGE_END}")
    print(f"IP range: {BASE_IP}{IP_START}-{BASE_IP}{IP_START + 99}")
    print("=" * 50)
    app.run(host='0.0.0.0', port=5000, debug=False)

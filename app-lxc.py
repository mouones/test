#!/usr/bin/env python3
from flask import Flask, request, jsonify
import subprocess
import time

app = Flask(__name__)

# LXC Configuration
TEMPLATE = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
CT_RANGE_START = 300
BASE_IP = "192.168.171."
IP_START = 200
GATEWAY = "192.168.171.2"
NETMASK = "24"
PASSWORD = "rootpass123"

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

@app.route('/deploy', methods=['POST'])
def deploy():
    """Deploy a new LXC container with the application"""
    data = request.json
    app_name = data.get('name', 'app')
    framework = data.get('framework', 'python')
    repo = data.get('repo')

    if not repo:
        return jsonify({'error': 'repo required'}), 400

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

        # Install Python stack
        run_cmd(f"pct exec {ctid} -- bash -c 'apt-get update && apt-get install -y python3 python3-pip python3-venv git'")

        # Clone and setup app
        run_cmd(f"pct exec {ctid} -- bash -c 'cd /opt && git clone {repo} app'")

        # Setup virtual environment and install dependencies
        run_cmd(f"""pct exec {ctid} -- bash -c '
            cd /opt/app && \
            python3 -m venv venv && \
            . venv/bin/activate && \
            if [ -f requirements.txt ]; then pip install -r requirements.txt; fi'
        """)

        # Create systemd service to run the app
        service_content = f"""[Unit]
Description={app_name} Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/app
Environment="PATH=/opt/app/venv/bin"
ExecStart=/opt/app/venv/bin/python app.py
Restart=always

[Install]
WantedBy=multi-user.target
"""
        
        run_cmd(f"pct exec {ctid} -- bash -c 'cat > /etc/systemd/system/{app_name}.service' <<'EOF'\n{service_content}\nEOF")
        run_cmd(f"pct exec {ctid} -- systemctl enable {app_name}")
        run_cmd(f"pct exec {ctid} -- systemctl start {app_name}")

        return jsonify({
            'status': 'success',
            'ctid': ctid,
            'name': app_name,
            'ip': ip,
            'framework': framework,
            'repo': repo,
            'url': f'http://{ip}:8000',
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

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

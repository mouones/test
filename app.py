#!/usr/bin/env python3
from flask import Flask, request, jsonify
import subprocess
import json
import time

app = Flask(__name__)

TEMPLATE_ID = 9000
VM_RANGE_START = 1100
BASE_IP = "192.168.171."
IP_START = 150
GATEWAY = "192.168.171.2"
NETMASK = "24"

def run_cmd(cmd):
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout.strip()

def get_next_vmid():
    used = set()
    output = run_cmd("qm list | awk 'NR>1{print $1}'")
    if output:
        used.update(int(x) for x in output.split('\n') if x)
    for vmid in range(VM_RANGE_START, VM_RANGE_START + 100):
        if vmid not in used:
            return vmid
    return None

def get_static_ip(vmid):
    offset = vmid - VM_RANGE_START
    return f"{BASE_IP}{IP_START + offset}"

@app.route('/deploy', methods=['POST'])
def deploy():
    data = request.json
    app_name = data.get('name', 'app')
    framework = data.get('framework', 'python')
    repo = data.get('repo')
    
    if not repo:
        return jsonify({'error': 'repo required'}), 400
    
    vmid = get_next_vmid()
    if not vmid:
        return jsonify({'error': 'No VMID available'}), 500
    
    ip = get_static_ip(vmid)
    
    run_cmd(f"qm clone {TEMPLATE_ID} {vmid} --name {app_name} --full")
    run_cmd(f"qm set {vmid} --cores 2 --memory 2048")
    run_cmd(f"qm set {vmid} --ipconfig0 ip={ip}/{NETMASK},gw={GATEWAY}")
    run_cmd(f"qm start {vmid}")
    
    return jsonify({
        'status': 'success',
        'vmid': vmid,
        'name': app_name,
        'ip': ip,
        'framework': framework,
        'repo': repo,
        'ssh': f'ssh root@{ip}',
        'password': 'rootpass123'
    })

@app.route('/list', methods=['GET'])
def list_vms():
    output = run_cmd("qm list")
    return jsonify({'vms': output})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

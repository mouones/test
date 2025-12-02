#!/usr/bin/env python3
from flask import Flask, render_template, request, jsonify, redirect, url_for
import requests
import json

app = Flask(__name__)

# Proxmox PaaS API endpoint
PAAS_API = "http://192.168.171.140:5000"

# Framework configurations
FRAMEWORKS = {
    'python-flask': {
        'name': 'Python Flask',
        'icon': '🐍',
        'port': 8000,
        'description': 'Lightweight Python web framework'
    },
    'python-django': {
        'name': 'Python Django',
        'icon': '🎸',
        'port': 8000,
        'description': 'Full-featured Python web framework'
    },
    'nodejs-express': {
        'name': 'Node.js Express',
        'icon': '📗',
        'port': 3000,
        'description': 'Fast Node.js web framework'
    },
    'php-laravel': {
        'name': 'PHP Laravel',
        'icon': '🔴',
        'port': 8000,
        'description': 'Elegant PHP web framework'
    }
}

@app.route('/')
def index():
    return render_template('index.html', frameworks=FRAMEWORKS)

@app.route('/deploy', methods=['POST'])
def deploy():
    data = request.json
    
    # Prepare deployment request
    deploy_data = {
        'name': data.get('name'),
        'repo': data.get('repo'),
        'framework': data.get('framework'),
        'type': data.get('type', 'lxc')  # lxc or vm
    }
    
    try:
        # Call Proxmox PaaS API
        response = requests.post(f"{PAAS_API}/deploy", json=deploy_data, timeout=300)
        result = response.json()
        
        if response.status_code == 200:
            return jsonify({
                'success': True,
                'data': result
            })
        else:
            return jsonify({
                'success': False,
                'error': result.get('error', 'Deployment failed')
            }), 400
            
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/containers')
def containers():
    try:
        response = requests.get(f"{PAAS_API}/list")
        data = response.json()
        return jsonify(data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/status/<int:ctid>')
def status(ctid):
    try:
        response = requests.get(f"{PAAS_API}/status/{ctid}")
        return jsonify(response.json())
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/delete/<int:ctid>', methods=['DELETE'])
def delete(ctid):
    try:
        response = requests.delete(f"{PAAS_API}/delete/{ctid}")
        return jsonify(response.json())
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)

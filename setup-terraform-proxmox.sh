#!/bin/bash
# Proxmox-local Terraform deployment script
# Runs Terraform directly on Proxmox using local provider

cd /root/proxmox-paas

# Create Terraform directory
mkdir -p terraform-local
cd terraform-local

# Create main.tf for local Proxmox deployment
cat > main.tf <<'TFEOF'
terraform {
  required_version = ">= 1.0"
}

# Use null provider for local execution
provider "null" {}

# Deploy containers using local pct commands
resource "null_resource" "lxc_container" {
  for_each = var.containers

  # Create container
  provisioner "local-exec" {
    command = <<-EOC
      pct create ${each.value.vmid} local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
        --hostname ${each.value.hostname} \
        --memory ${each.value.memory} \
        --cores ${each.value.cores} \
        --net0 name=eth0,bridge=vmbr0,ip=${each.value.ip}/24,gw=192.168.171.2 \
        --password thenoob123. \
        --features nesting=1 \
        --unprivileged 1 \
        --rootfs local-lvm:8 \
        --onboot 1
      
      pct start ${each.value.vmid}
      sleep 15
      
      # Install packages
      pct exec ${each.value.vmid} -- bash -c 'DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y ${join(" ", each.value.packages)}'
      
      # Clone repo
      pct exec ${each.value.vmid} -- bash -c 'cd /opt && git clone ${each.value.repo} app'
      
      # Setup commands
      ${join("\n      ", [for cmd in each.value.setup_commands : "pct exec ${each.value.vmid} -- bash -c '${cmd}'"])}
      
      # Create systemd service
      cat > /tmp/service-${each.value.vmid}.service <<SVC
[Unit]
Description=${each.value.hostname} (${each.value.framework})
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/app
Environment="PATH=/opt/app/venv/bin:/root/.cargo/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/bin/bash -c '${each.value.start_command}'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SVC
      
      pct push ${each.value.vmid} /tmp/service-${each.value.vmid}.service /etc/systemd/system/${each.value.hostname}.service
      pct exec ${each.value.vmid} -- systemctl daemon-reload
      pct exec ${each.value.vmid} -- systemctl enable ${each.value.hostname}
      pct exec ${each.value.vmid} -- systemctl start ${each.value.hostname}
    EOC
  }
}

variable "containers" {
  type = map(object({
    vmid            = number
    hostname        = string
    ip              = string
    cores           = number
    memory          = number
    framework       = string
    repo            = string
    packages        = list(string)
    setup_commands  = list(string)
    start_command   = string
  }))
}
TFEOF

# Create containers.auto.tfvars
cat > containers.auto.tfvars <<'VARSEOF'
containers = {
  flask = {
    vmid     = 303
    hostname = "tf-flask"
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
    hostname = "tf-django"
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
}
VARSEOF

echo "Terraform configuration created!"
echo "Run: cd /root/proxmox-paas/terraform-local && terraform init && terraform apply"

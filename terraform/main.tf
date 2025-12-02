terraform {
  required_version = ">= 1.0"
  
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 2.9"
    }
  }
}

provider "proxmox" {
  pm_api_url      = var.proxmox_api_url
  pm_user         = var.proxmox_user
  pm_password     = var.proxmox_password
  pm_tls_insecure = true
  pm_log_enable   = true
  pm_log_file     = "terraform-plugin-proxmox.log"
  pm_log_levels = {
    _default    = "debug"
    _capturelog = ""
  }
}

# LXC Container resource
resource "proxmox_lxc" "app_container" {
  for_each = var.containers

  target_node  = var.proxmox_node
  hostname     = each.value.hostname
  ostemplate   = var.template_name
  password     = var.container_password
  unprivileged = true
  onboot       = true
  start        = true
  vmid         = each.value.vmid

  # Resources
  cores  = each.value.cores
  memory = each.value.memory
  swap   = each.value.swap

  # Root filesystem
  rootfs {
    storage = "local-lvm"
    size    = each.value.disk_size
  }

  # Network configuration
  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "${each.value.ip}/${var.netmask}"
    gw     = var.gateway
  }

  # Features
  features {
    nesting = true
  }

  # Provisioning
  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y ${join(" ", each.value.packages)}",
      "mkdir -p /opt/app"
    ]

    connection {
      type     = "ssh"
      user     = "root"
      password = var.container_password
      host     = each.value.ip
    }
  }

  # Framework-specific setup
  provisioner "remote-exec" {
    inline = each.value.setup_commands

    connection {
      type     = "ssh"
      user     = "root"
      password = var.container_password
      host     = each.value.ip
    }
  }

  # Deploy application
  provisioner "remote-exec" {
    inline = [
      "cd /opt && git clone ${each.value.repo} app || true",
      "cd /opt/app && ${each.value.build_command}"
    ]

    connection {
      type     = "ssh"
      user     = "root"
      password = var.container_password
      host     = each.value.ip
    }
  }

  # Create systemd service
  provisioner "file" {
    content = templatefile("${path.module}/templates/systemd.service.tpl", {
      app_name        = each.value.hostname
      framework_name  = each.value.framework
      working_dir     = "/opt/app"
      exec_start      = each.value.start_command
    })
    destination = "/etc/systemd/system/${each.value.hostname}.service"

    connection {
      type     = "ssh"
      user     = "root"
      password = var.container_password
      host     = each.value.ip
    }
  }

  # Enable and start service
  provisioner "remote-exec" {
    inline = [
      "systemctl daemon-reload",
      "systemctl enable ${each.value.hostname}",
      "systemctl start ${each.value.hostname}"
    ]

    connection {
      type     = "ssh"
      user     = "root"
      password = var.container_password
      host     = each.value.ip
    }
  }

  lifecycle {
    create_before_destroy = false
  }
}

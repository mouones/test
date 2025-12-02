output "container_details" {
  description = "Details of all deployed containers"
  value = {
    for k, v in proxmox_lxc.app_container : k => {
      vmid     = v.vmid
      hostname = v.hostname
      ip       = v.network[0].ip
      cores    = v.cores
      memory   = v.memory
      url      = "http://${split("/", v.network[0].ip)[0]}:${lookup(var.containers[k], "port", 8000)}"
    }
  }
}

output "container_ips" {
  description = "IP addresses of deployed containers"
  value = {
    for k, v in proxmox_lxc.app_container : k => split("/", v.network[0].ip)[0]
  }
}

output "container_urls" {
  description = "Access URLs for deployed applications"
  value = {
    for k, v in proxmox_lxc.app_container : k => "http://${split("/", v.network[0].ip)[0]}:${lookup(var.containers[k], "port", 8000)}"
  }
}

output "ssh_commands" {
  description = "SSH commands to access containers"
  value = {
    for k, v in proxmox_lxc.app_container : k => "ssh root@${split("/", v.network[0].ip)[0]}"
  }
}

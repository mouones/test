variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://192.168.171.140:8006/api2/json"
}

variable "proxmox_user" {
  description = "Proxmox user (format: user@pam or user@pve)"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}

variable "template_name" {
  description = "LXC template to use"
  type        = string
  default     = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
}

variable "container_password" {
  description = "Root password for containers"
  type        = string
  sensitive   = true
  default     = "rootpass123"
}

variable "gateway" {
  description = "Network gateway"
  type        = string
  default     = "192.168.171.2"
}

variable "netmask" {
  description = "Network netmask (CIDR notation)"
  type        = string
  default     = "24"
}

variable "containers" {
  description = "Map of containers to deploy"
  type = map(object({
    vmid            = number
    hostname        = string
    ip              = string
    cores           = number
    memory          = number
    swap            = number
    disk_size       = string
    framework       = string
    repo            = string
    packages        = list(string)
    setup_commands  = list(string)
    build_command   = string
    start_command   = string
  }))
  default = {}
}

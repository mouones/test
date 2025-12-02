# Terraform Configuration for Proxmox PaaS

This directory contains Terraform configurations to deploy and manage containerized applications on Proxmox VE.

## 🚀 Features

- **Infrastructure as Code**: Define all containers in version-controlled configuration
- **10 Framework Support**: Pre-configured for Flask, Django, FastAPI, Express, Next.js, Laravel, Go, Rust, Ruby, and Static sites
- **Idempotent Deployments**: Safe to run multiple times
- **Resource Management**: Automatic IP and VMID management
- **Systemd Integration**: Automatic service creation and management

## 📋 Prerequisites

1. **Terraform installed**:
   ```powershell
   # Install via Chocolatey
   choco install terraform
   
   # Or download from https://www.terraform.io/downloads
   ```

2. **Proxmox API access**:
   - Proxmox host accessible
   - Root credentials or API token
   - SSH access to containers

3. **LXC template available**:
   - Ubuntu 22.04 template downloaded on Proxmox
   - Template path: `local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst`

## 🏗️ File Structure

```
terraform/
├── main.tf                    # Main Terraform configuration
├── variables.tf               # Variable definitions
├── outputs.tf                 # Output definitions
├── terraform.tfvars.example   # Example configuration
├── frameworks.auto.tfvars     # All 10 framework configs
├── templates/
│   └── systemd.service.tpl    # Systemd service template
└── README.md                  # This file
```

## ⚙️ Configuration

### 1. Create terraform.tfvars

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
proxmox_api_url    = "https://192.168.171.140:8006/api2/json"
proxmox_user       = "root@pam"
proxmox_password   = "your-proxmox-password"
proxmox_node       = "pve"
container_password = "rootpass123"
gateway           = "192.168.171.2"
```

### 2. Review Framework Configuration

The file `frameworks.auto.tfvars` contains all 10 framework configurations. You can:

- **Deploy all**: Use as-is
- **Deploy specific frameworks**: Comment out unwanted frameworks
- **Customize**: Modify VMIDs, IPs, resources, or commands

## 🎯 Usage

### Initialize Terraform

```powershell
cd C:\Users\mns\Documents\terminal\cloud\prox\terraform
terraform init
```

### Plan Deployment

```powershell
# See what will be created
terraform plan
```

### Deploy All Frameworks

```powershell
# Deploy all 10 frameworks
terraform apply
```

### Deploy Specific Frameworks

```powershell
# Deploy only Flask and Express
terraform apply -target=proxmox_lxc.app_container["flask"] -target=proxmox_lxc.app_container["express"]
```

### View Outputs

```powershell
# Show all container details
terraform output

# Show specific output
terraform output container_ips
terraform output container_urls
```

### Destroy Resources

```powershell
# Destroy all containers
terraform destroy

# Destroy specific container
terraform destroy -target=proxmox_lxc.app_container["flask"]
```

## 📊 Framework Configurations

| Framework | VMID | IP | Port | Resources |
|-----------|------|-----|------|-----------|
| Python Flask | 303 | 192.168.171.203 | 8000 | 2 CPU, 2GB RAM |
| Python Django | 304 | 192.168.171.204 | 8000 | 2 CPU, 2GB RAM |
| Python FastAPI | 305 | 192.168.171.205 | 8000 | 2 CPU, 2GB RAM |
| Node.js Express | 306 | 192.168.171.206 | 3000 | 2 CPU, 2GB RAM |
| Next.js | 307 | 192.168.171.207 | 3000 | 2 CPU, 2GB RAM |
| PHP Laravel | 308 | 192.168.171.208 | 8000 | 2 CPU, 2GB RAM |
| Go Gin | 309 | 192.168.171.209 | 8080 | 2 CPU, 2GB RAM |
| Rust Actix | 310 | 192.168.171.210 | 8080 | 2 CPU, 2GB RAM |
| Ruby on Rails | 311 | 192.168.171.211 | 3000 | 2 CPU, 2GB RAM |
| Static (Nginx) | 312 | 192.168.171.212 | 80 | 1 CPU, 1GB RAM |

## 🔄 Workflow Examples

### Example 1: Deploy Python Stack

```powershell
# Deploy Flask, Django, and FastAPI
terraform apply \
  -target=proxmox_lxc.app_container["flask"] \
  -target=proxmox_lxc.app_container["django"] \
  -target=proxmox_lxc.app_container["fastapi"]
```

### Example 2: Update Single Container

```powershell
# Modify frameworks.auto.tfvars (e.g., change Flask memory to 4GB)
# Then apply only that change
terraform apply -target=proxmox_lxc.app_container["flask"]
```

### Example 3: Replace Failed Container

```powershell
# Destroy and recreate
terraform destroy -target=proxmox_lxc.app_container["django"]
terraform apply -target=proxmox_lxc.app_container["django"]
```

### Example 4: Scale Up Resources

Edit `frameworks.auto.tfvars`:
```hcl
flask = {
  # ... other config ...
  cores  = 4      # Changed from 2
  memory = 4096   # Changed from 2048
}
```

Apply changes:
```powershell
terraform apply -target=proxmox_lxc.app_container["flask"]
```

## 🛠️ Customization

### Add Custom Framework

Add to `frameworks.auto.tfvars`:
```hcl
myframework = {
  vmid           = 313
  hostname       = "my-custom-app"
  ip             = "192.168.171.213"
  cores          = 2
  memory         = 2048
  swap           = 512
  disk_size      = "8G"
  framework      = "My Framework"
  repo           = "https://github.com/user/repo"
  packages       = ["package1", "package2"]
  setup_commands = [
    "command1",
    "command2"
  ]
  build_command = "build command"
  start_command = "start command"
  port          = 8080
}
```

### Use Different Repository

Modify the `repo` field in `frameworks.auto.tfvars`:
```hcl
flask = {
  # ... other config ...
  repo = "https://github.com/your-username/your-flask-app"
}
```

## 📝 State Management

Terraform maintains state in `terraform.tfstate`. This file:

- **Tracks deployed resources**
- **Should NOT be committed to git** (contains sensitive data)
- **Should be backed up** for disaster recovery

### Backup State

```powershell
# Backup current state
cp terraform.tfstate terraform.tfstate.backup

# Or use remote backend (S3, Terraform Cloud, etc.)
```

## 🔍 Troubleshooting

### Issue: Provider Authentication Failed

```
Error: error creating Proxmox client: error checking Proxmox VE version
```

**Solution**: Check credentials in `terraform.tfvars`:
```powershell
# Test Proxmox API manually
curl -k https://192.168.171.140:8006/api2/json/version
```

### Issue: Template Not Found

```
Error: template not found
```

**Solution**: Download Ubuntu template on Proxmox:
```bash
ssh root@192.168.171.140
pveam update
pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst
```

### Issue: VMID Already In Use

```
Error: VMID 303 already exists
```

**Solution**: Either:
1. Destroy existing container first
2. Change VMID in configuration
3. Import existing resource: `terraform import proxmox_lxc.app_container["flask"] pve/lxc/303`

### Issue: SSH Connection Failed

```
Error: connection refused
```

**Solution**: 
1. Ensure container is running
2. Wait longer for container to start (increase timeouts)
3. Check network connectivity: `ping 192.168.171.203`

## 🚦 Best Practices

1. **Version Control**: Commit `.tf` files, exclude `terraform.tfstate` and `terraform.tfvars`
2. **Plan Before Apply**: Always run `terraform plan` first
3. **Incremental Changes**: Deploy/test one framework at a time initially
4. **Backup State**: Regularly backup `terraform.tfstate`
5. **Document Changes**: Comment modifications in `.tfvars` files
6. **Use Variables**: Don't hardcode values in `main.tf`
7. **Test Locally**: Verify configurations work manually before automating

## 📚 Advanced Usage

### Remote State Backend

Store state in remote backend:
```hcl
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "proxmox/terraform.tfstate"
    region = "us-east-1"
  }
}
```

### Modules

Organize as modules:
```
terraform/
├── modules/
│   ├── container/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── framework/
│       └── ...
└── main.tf
```

### Workspaces

Manage multiple environments:
```powershell
# Create dev environment
terraform workspace new dev
terraform apply

# Switch to production
terraform workspace new prod
terraform apply
```

## 🔗 Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [Proxmox Provider](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

## 🎯 Quick Start

```powershell
# 1. Initialize
cd C:\Users\mns\Documents\terminal\cloud\prox\terraform
terraform init

# 2. Configure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your credentials

# 3. Plan
terraform plan

# 4. Deploy
terraform apply

# 5. Access
terraform output container_urls
```

---

**Status**: Ready for deployment ✅  
**Last Updated**: December 2, 2024  
**Terraform Version**: >= 1.0  
**Provider Version**: telmate/proxmox ~> 2.9

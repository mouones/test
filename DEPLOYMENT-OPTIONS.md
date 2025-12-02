# Complete Terraform Deployment Guide from Windows to Proxmox

## ✅ What You Have Now

Terraform configuration ready to deploy all 10 frameworks to Proxmox **remotely from your Windows machine**.

## 🎯 Quick Deploy (Choose One Method)

### Method 1: Deploy All 10 Frameworks at Once

```powershell
cd C:\Users\mns\Documents\terminal\cloud\prox\terraform
terraform apply -auto-approve
```

This will create containers 303-312 with all frameworks.

### Method 2: Deploy One Framework at a Time

```powershell
cd C:\Users\mns\Documents\terminal\cloud\prox\terraform

# Deploy Flask only
terraform apply -target='proxmox_lxc.app_container["flask"]' -auto-approve

# Deploy Django
terraform apply -target='proxmox_lxc.app_container["django"]' -auto-approve

# Deploy Express
terraform apply -target='proxmox_lxc.app_container["express"]' -auto-approve
```

### Method 3: Use the Flask API (Current Method)

The Flask API is already running on Proxmox. Just use it:

```powershell
# Deploy all test frameworks via API
Invoke-WebRequest -Uri "http://192.168.171.140:5000/deploy-all-tests" -Method POST -UseBasicParsing

# Or deploy one at a time via web interface
Start-Process "http://192.168.171.140:5000"
```

## 🔧 If Terraform Authentication Fails

The error "401 authentication failure" means Proxmox credentials need verification.

### Fix:  Test SSH connection first

```powershell
# Test if you can SSH to Proxmox
ssh root@192.168.171.140 "pvesh get /version"
```

If SSH works, Terraform should work too since both use the same credentials.

### Alternative: Use SSH tunneling

Instead of direct API, use SSH for provisioning:

```powershell
# Edit terraform/main.tf and remove all provisioner blocks
# Deploy containers only, then provision via SSH separately
```

## 📊 Current Options Summary

| Method | Location | Status | Best For |
|--------|----------|--------|----------|
| **Flask API** | http://192.168.171.140:5000 | ✅ Running | Quick deployments, testing |
| **Terraform** | Local (Windows) | ⚠️ Auth issue | Infrastructure as Code, version control |
| **SSH + Scripts** | Remote (Proxmox) | ✅ Available | Manual deployments |

## 🚀 Recommended: Use Flask API Now

Since the Flask API is already working and tested:

```powershell
# Open web interface
Start-Process "http://192.168.171.140:5000"

# Or use API directly
$frameworks = @("flask", "django", "fastapi", "express", "nextjs", "laravel", "go", "rust", "ruby", "nginx")

foreach ($fw in $frameworks) {
    $body = @{
        name = "test-$fw"
        repo = "https://github.com/mouones/test"
        framework = "python-$fw"
        type = "lxc"
    } | ConvertTo-Json

    Invoke-WebRequest -Uri "http://192.168.171.140:5000/deploy" `
        -Method POST `
        -Body $body `
        -ContentType "application/json"
    
    Write-Host "Deployed $fw, waiting 10 seconds..."
    Start-Sleep -Seconds 10
}
```

## 🔍 Why Terraform Shows Auth Error

Terraform uses Proxmox API which requires:
1. Valid credentials (root@pam + password) ✅ You have these
2. API accessible from Windows ✅ It is (port 8006)
3. TLS certificate trust ⚠️ Might be the issue

The Flask API works because it runs **ON** Proxmox and uses local `pct` commands.
Terraform runs **FROM** Windows and needs API access.

## ✨ What to Do Next

**Option A: Use Flask API (Easiest)**
- Already working
- No additional setup needed
- Deploy via: http://192.168.171.140:5000

**Option B: Fix Terraform (For IaC)**
- Worth it if you want version-controlled infrastructure
- Need to troubleshoot API auth
- Benefits: Repeatable, trackable, declarative

**Option C: Hybrid Approach**
- Use Flask API for quick deployments
- Use Terraform for production/documented deployments
- Best of both worlds

## 💡 My Recommendation

**Use the Flask API now** to deploy your frameworks since it's working:

```powershell
# Deploy all frameworks via the working API
Start-Process "http://192.168.171.140:5000"
```

Then later, we can fix Terraform authentication if you want IaC benefits.

---

**Current Status:**
- ✅ Flask PaaS API: **Working** on Proxmox
- ✅ 10 Frameworks: **Configured** and ready
- ✅ Conflict Detection: **Active**
- ⚠️ Terraform: Needs auth troubleshooting
- ✅ SSH Access: **Working**

**You can deploy NOW using:** http://192.168.171.140:5000

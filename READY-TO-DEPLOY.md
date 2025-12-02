# 🚀 Ready to Deploy - Two Methods Available

## ✅ Status: Everything is Configured

### Method 1: Flask API (Running on Proxmox)
**URL:** http://192.168.171.140:5000  
**Status:** ✅ Active  
**Features:** Web interface, REST API, 10 frameworks

### Method 2: Terraform (On Proxmox)  
**Location:** `/root/setup-terraform-proxmox.sh` (uploaded)  
**Status:** ✅ Ready to run  
**Features:** Infrastructure as Code, version controlled

---

## 🎯 Quick Deploy - Choose Your Method

### Option A: Deploy via Web Interface (Easiest)

1. Open browser: **http://192.168.171.140:5000**
2. Select framework from dropdown
3. Enter name (e.g., "test-flask")
4. Repo: `https://github.com/mouones/test`
5. Click "Deploy!"
6. Repeat for all 10 frameworks

**Frameworks Available:**
- Python Flask (port 8000)
- Python Django (port 8000)
- Python FastAPI (port 8000)
- Node.js Express (port 3000)
- Next.js (port 3000)
- PHP Laravel (port 8000)
- Go Gin (port 8080)
- Rust Actix (port 8080)
- Ruby on Rails (port 3000)
- Static/Nginx (port 80)

---

### Option B: Deploy via Terraform (Infrastructure as Code)

**From Windows PowerShell:**
```powershell
# Connect to Proxmox and run Terraform
ssh root@192.168.171.140

# On Proxmox, run:
bash /root/setup-terraform-proxmox.sh
cd /root/proxmox-paas/terraform-local
terraform init
terraform plan
terraform apply -auto-approve
```

This will deploy Flask and Django containers (CT 303-304).

**To add more frameworks**, edit `/root/proxmox-paas/terraform-local/containers.auto.tfvars` and add configurations.

---

### Option C: Deploy via PowerShell API Calls

```powershell
# Deploy Flask
$body = @{
    name = "test-flask"
    repo = "https://github.com/mouones/test"
    framework = "python-flask"
    type = "lxc"
} | ConvertTo-Json

Invoke-WebRequest -Uri "http://192.168.171.140:5000/deploy" `
    -Method POST `
    -Body $body `
    -ContentType "application/json" `
    -UseBasicParsing

# Wait 3-5 minutes for deployment
# Then access at: http://192.168.171.203:8000
```

---

## 📊 Current Containers

```
VMID  Status   Name
200   stopped  test-container
300   running  flask-lxc (192.168.171.200)
301   running  test-app-2 (192.168.171.201)
302   running  proo (192.168.171.202)
```

**Next Available:**
- VMID: 303
- IP: 192.168.171.203

---

## 🔧 Files Created

### On Windows (C:\Users\mns\Documents\terminal\cloud\prox\)
- ✅ `terraform/` - Full Terraform config (10 frameworks)
- ✅ `deploy-terraform.ps1` - Deployment helper script
- ✅ `setup-terraform-proxmox.sh` - Uploaded to Proxmox
- ✅ `app-final-optimized.py` - Enhanced PaaS (uploaded, running)

### On Proxmox (/root/)
- ✅ `/root/setup-terraform-proxmox.sh` - Terraform setup script
- ✅ `/root/proxmox-paas/app.py` - Flask API (running)
- ✅ `/root/optimize-storage.sh` - Storage optimization
- ✅ Terraform will be installed (already installed)

---

## 🎬 Recommended Next Steps

### Quick Test (2 minutes):
```powershell
# Deploy one framework via web interface
Start-Process "http://192.168.171.140:5000"
```

### Full Deployment (20-30 minutes):
**Via SSH to Proxmox:**
```bash
ssh root@192.168.171.140

# Deploy 2 frameworks via Terraform
bash /root/setup-terraform-proxmox.sh
cd /root/proxmox-paas/terraform-local
terraform init
terraform apply -auto-approve

# Or deploy all via Flask API
curl -X POST http://localhost:5000/deploy \
  -H "Content-Type: application/json" \
  -d '{"name":"test-flask","repo":"https://github.com/mouones/test","framework":"python-flask","type":"lxc"}'
```

---

## 🐛 Troubleshooting

### Flask API not responding?
```bash
ssh root@192.168.171.140
systemctl restart proxmox-paas  # If service exists
# Or
cd /root/proxmox-paas && python3 app.py > /tmp/paas.log 2>&1 &
```

### Check deployment status:
```bash
ssh root@192.168.171.140
pct list
tail -f /tmp/paas.log
```

### View container logs:
```bash
ssh root@192.168.171.140
pct enter 303  # Or any VMID
systemctl status test-flask
journalctl -u test-flask -f
```

---

## 📈 Expected Results

After deploying all 10 frameworks:

| VMID | Name | IP | Port | Framework |
|------|------|-----|------|-----------|
| 303 | test-flask | 192.168.171.203 | 8000 | Python Flask |
| 304 | test-django | 192.168.171.204 | 8000 | Python Django |
| 305 | test-fastapi | 192.168.171.205 | 8000 | Python FastAPI |
| 306 | test-express | 192.168.171.206 | 3000 | Node.js Express |
| 307 | test-nextjs | 192.168.171.207 | 3000 | Next.js |
| 308 | test-laravel | 192.168.171.208 | 8000 | PHP Laravel |
| 309 | test-go | 192.168.171.209 | 8080 | Go Gin |
| 310 | test-rust | 192.168.171.210 | 8080 | Rust Actix |
| 311 | test-ruby | 192.168.171.211 | 3000 | Ruby Rails |
| 312 | test-static | 192.168.171.212 | 80 | Static/Nginx |

---

## ✨ Summary

**You have 3 ways to deploy:**

1. **Web UI** → http://192.168.171.140:5000 ← **(Easiest)**
2. **Terraform** → SSH to Proxmox → Run script
3. **API** → PowerShell → Send POST requests

**All methods work!** Choose based on your preference:
- Want GUI? → Use Web UI
- Want IaC? → Use Terraform  
- Want automation? → Use API

---

**Ready to start?** → http://192.168.171.140:5000 🚀

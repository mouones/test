# 📋 Deployment Checklist

## Pre-Deployment

- [ ] Proxmox VE 6.14+ installed and accessible
- [ ] SSH access to Proxmox as root
- [ ] Network configured (192.168.171.0/24)
- [ ] At least 20GB free storage
- [ ] Files ready: `install-proxmox.sh`, `templates-enhanced/index.html`

## Installation Steps

### 1. Upload Files
```powershell
scp install-proxmox.sh root@192.168.171.140:/root/
scp templates-enhanced/index.html root@192.168.171.140:/root/
scp app-lxc-enhanced.py root@192.168.171.140:/root/
```
- [ ] install-proxmox.sh uploaded
- [ ] index.html uploaded
- [ ] app-lxc-enhanced.py uploaded (optional, script creates it)

### 2. Run Installation
```bash
ssh root@192.168.171.140
chmod +x /root/install-proxmox.sh
/root/install-proxmox.sh
```
- [ ] SSH connection established
- [ ] Script executed successfully
- [ ] No errors in output

### 3. Setup Templates
```bash
mkdir -p /root/proxmox-paas/templates
mv /root/index.html /root/proxmox-paas/templates/
```
- [ ] Templates directory created
- [ ] index.html moved to templates folder

### 4. Configure App (if using manual setup)
```bash
cd /root/proxmox-paas
cp /root/app-lxc-enhanced.py app.py
```
- [ ] App file in place
- [ ] Permissions correct (chmod +x app.py)

### 5. Start Service
```bash
systemctl daemon-reload
systemctl enable proxmox-paas
systemctl start proxmox-paas
systemctl status proxmox-paas
```
- [ ] Service loaded
- [ ] Service enabled
- [ ] Service started
- [ ] Status shows "active (running)"

## Verification

### 6. Check Service
```bash
systemctl status proxmox-paas
```
Expected output:
```
● proxmox-paas.service - Proxmox PaaS Platform
   Loaded: loaded (/etc/systemd/system/proxmox-paas.service; enabled)
   Active: active (running) since ...
```
- [ ] Service is active
- [ ] No errors in logs

### 7. Test API
```bash
curl http://localhost:5000/frameworks
```
Expected: JSON response with frameworks list
- [ ] API responds
- [ ] Returns JSON with 10 frameworks

### 8. Test Web Interface
```bash
curl http://localhost:5000/
```
Expected: HTML content
- [ ] Returns HTML
- [ ] No 404 or 500 errors

### 9. Check Logs
```bash
journalctl -u proxmox-paas -n 50
```
- [ ] No critical errors
- [ ] Shows Gunicorn workers started
- [ ] Shows "Running on http://0.0.0.0:5000"

### 10. Verify Templates
```bash
ls -la /root/proxmox-paas/templates/index.html
```
- [ ] File exists
- [ ] File size > 10KB
- [ ] Readable permissions

### 11. Check LXC Template
```bash
ls -lh /var/lib/vz/template/cache/ubuntu-22.04*
```
- [ ] Template exists
- [ ] File size ~200MB+

## Access from Network

### 12. Access from Browser
Open: `http://192.168.171.140:5000`
- [ ] Web interface loads
- [ ] CSS styles applied (purple gradient)
- [ ] Framework cards visible (10 cards)
- [ ] Stats show "10" frameworks

### 13. Test Framework Loading
Check browser console (F12):
- [ ] No JavaScript errors
- [ ] `/frameworks` API call succeeds
- [ ] Framework cards populated

## First Deployment Test

### 14. Deploy Test Application
In web interface:
- App Name: `test-deploy`
- Repo: `https://github.com/mouones/test`
- Framework: `Python Flask 🐍`
- Type: `LXC Container`
- Click `Deploy Application`

- [ ] Deployment starts (spinner shows)
- [ ] Status changes to "Deploying..."
- [ ] Wait 60-90 seconds
- [ ] Success message appears
- [ ] Container ID shown (e.g., 300)
- [ ] IP address shown (e.g., 192.168.171.200)
- [ ] URL provided

### 15. Verify Container
```bash
pct list
```
- [ ] Container appears in list
- [ ] Status is "running"

### 16. Check Container Network
```bash
pct exec 300 -- ip addr show eth0
```
- [ ] IP address assigned (192.168.171.200)
- [ ] Gateway configured

### 17. Verify Application
```bash
curl http://192.168.171.200:8000
```
- [ ] App responds
- [ ] Returns expected content

### 18. Access from Browser
Open: `http://192.168.171.200:8000`
- [ ] Application loads
- [ ] No connection errors

## Service Management

### 19. Test Restart
```bash
systemctl restart proxmox-paas
sleep 5
systemctl status proxmox-paas
```
- [ ] Restarts without errors
- [ ] Comes back online quickly
- [ ] Web interface still accessible

### 20. Test Auto-Start
```bash
systemctl is-enabled proxmox-paas
```
Expected output: `enabled`
- [ ] Auto-start is enabled

## Cleanup Test Container (Optional)

### 21. Delete Test Container
Via web interface:
- Click "Delete" button for container 300
- Confirm deletion

Or via API:
```bash
curl -X DELETE http://192.168.171.140:5000/delete/300
```
- [ ] Container deleted
- [ ] No longer in `pct list`

## Final Checks

### 22. Review Documentation
- [ ] README.md available
- [ ] INSTALLATION.md available
- [ ] SUMMARY.md available
- [ ] Documentation matches deployment

### 23. Security Review
- [ ] Consider changing default password
- [ ] Review firewall rules
- [ ] Plan for SSL/HTTPS (optional)
- [ ] Backup configuration

### 24. Performance Check
```bash
free -h
df -h
ps aux | grep gunicorn
```
- [ ] Adequate free memory
- [ ] Adequate disk space
- [ ] Gunicorn workers running

## Troubleshooting

If anything fails, check:

### Service Won't Start
```bash
journalctl -u proxmox-paas -n 100
```
Common issues:
- Port 5000 already in use
- Templates directory missing
- Python dependencies missing
- File permissions incorrect

### Web Interface Not Loading
```bash
ls -la /root/proxmox-paas/templates/index.html
cat /root/proxmox-paas/templates/index.html | head -n 10
```
Common issues:
- index.html not in templates/
- Wrong file path
- File corrupted

### Deployment Fails
```bash
pct list
journalctl -u proxmox-paas -n 100
```
Common issues:
- LXC template missing
- Network misconfigured
- Insufficient storage
- Container ID conflict

### Cannot Access from Network
```bash
ss -tlnp | grep 5000
iptables -L -n | grep 5000
```
Common issues:
- Service listening on 127.0.0.1 instead of 0.0.0.0
- Firewall blocking port 5000
- Wrong IP address used

## Success Criteria

All these should be TRUE:
- ✅ Service running and enabled
- ✅ Web interface accessible from browser
- ✅ API responds to requests
- ✅ Can deploy applications successfully
- ✅ Containers get network access
- ✅ Applications are reachable
- ✅ Service auto-starts on boot
- ✅ No critical errors in logs

## Next Steps

After successful deployment:
1. Deploy production applications
2. Test all 10 frameworks
3. Set up monitoring
4. Configure backups
5. Implement SSL/HTTPS
6. Add user authentication
7. Document custom workflows
8. Scale resources as needed

---

**Estimated Time**: 15-30 minutes
**Difficulty**: Easy (with automated script)
**Support**: See INSTALLATION.md and README.md

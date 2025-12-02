#!/bin/bash
# Proxmox Space Cleanup Script

echo "=== Proxmox Space Cleanup ==="
echo ""

echo "Current disk usage:"
df -h
echo ""

echo "=== Checking VMs ==="
qm list
echo ""

echo "=== Checking Containers ==="
pct list
echo ""

echo "=== Stopping and removing ALL VMs ==="
for vmid in $(qm list | tail -n +2 | awk '{print $1}'); do
    echo "Processing VM $vmid..."
    # Unlock if locked
    qm unlock $vmid 2>/dev/null || true
    # Stop
    qm stop $vmid 2>/dev/null || true
    sleep 2
    # Destroy
    qm destroy $vmid --purge 2>/dev/null || true
    echo "VM $vmid removed"
done

echo ""
echo "=== Stopping and removing ALL Containers ==="
for ctid in $(pct list | tail -n +2 | awk '{print $1}'); do
    echo "Processing CT $ctid..."
    # Unlock if locked
    pct unlock $ctid 2>/dev/null || true
    # Stop
    pct stop $ctid 2>/dev/null || true
    sleep 2
    # Destroy
    pct destroy $ctid --purge 2>/dev/null || true
    echo "CT $ctid removed"
done

echo ""
echo "=== Removing backups ==="
du -sh /var/lib/vz/dump/ 2>/dev/null || true
rm -rf /var/lib/vz/dump/* 2>/dev/null || true
echo "Backups cleared"

echo ""
echo "=== Cleaning apt cache ==="
apt-get clean
apt-get autoclean
apt-get autoremove -y

echo ""
echo "=== Cleaning old logs ==="
journalctl --vacuum-time=7d

echo ""
echo "=== Final disk usage ==="
df -h

echo ""
echo "✅ Cleanup complete!"

#!/bin/bash
# Unlock and clean up stuck containers

echo "=== Unlocking and removing stuck containers ==="
for ct in {303..313}; do
    echo "Checking container $ct..."
    # Remove lock files
    rm -f /var/lock/pve-container-$ct.lck 2>/dev/null
    rm -f /var/lock/lxc/var/lib/lxc/$ct 2>/dev/null
    
    # Try to stop
    pct stop $ct 2>/dev/null
    sleep 2
    
    # Force destroy
    pct destroy $ct 2>/dev/null
done

echo ""
echo "=== Cleaning up any remaining LVM volumes ==="
for ct in {303..313}; do
    lvremove -f pve/vm-$ct-disk-0 2>/dev/null
done

echo ""
echo "=== Current containers after cleanup ==="
pct list

echo ""
echo "=== Now run deploy script ==="

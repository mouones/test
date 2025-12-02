#!/bin/bash
# Proxmox Storage Optimization Script
# Cleans up and optimizes storage for PaaS platform

set -e

echo "=========================================="
echo "Proxmox Storage Optimization"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Checking current storage usage...${NC}"
df -h | grep -E "Filesystem|pve-root|pve-data|/tmp"
echo ""

echo -e "${YELLOW}Step 2: Cleaning /tmp directory...${NC}"
du -sh /tmp 2>/dev/null || echo "Empty"
rm -rf /tmp/* 2>/dev/null || true
rm -rf /tmp/.* 2>/dev/null || true
echo -e "${GREEN}✓ /tmp cleaned${NC}"
echo ""

echo -e "${YELLOW}Step 3: Cleaning apt cache...${NC}"
apt-get clean
apt-get autoclean
apt-get autoremove -y
echo -e "${GREEN}✓ APT cache cleaned${NC}"
echo ""

echo -e "${YELLOW}Step 4: Cleaning old logs...${NC}"
journalctl --vacuum-time=7d
find /var/log -type f -name "*.log" -mtime +30 -delete 2>/dev/null || true
find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
echo -e "${GREEN}✓ Old logs cleaned${NC}"
echo ""

echo -e "${YELLOW}Step 5: Removing orphaned VM/CT disks...${NC}"
# Get list of active containers and VMs
ACTIVE_VMS=$(qm list 2>/dev/null | awk 'NR>1{print $1}' | tr '\n' '|' | sed 's/|$//')
ACTIVE_CTS=$(pct list 2>/dev/null | awk 'NR>1{print $1}' | tr '\n' '|' | sed 's/|$//')

echo "Active VMs: ${ACTIVE_VMS:-none}"
echo "Active CTs: ${ACTIVE_CTS:-none}"

# Find and remove orphaned LVM volumes
for LV in $(lvs --noheadings -o lv_name pve 2>/dev/null | grep -E "vm-|base-" | tr -d ' '); do
    VMID=$(echo $LV | grep -oP '\d+' | head -1)
    if [[ ! "$ACTIVE_VMS" =~ (^|[^0-9])$VMID($|[^0-9]) ]] && [[ ! "$ACTIVE_CTS" =~ (^|[^0-9])$VMID($|[^0-9]) ]]; then
        echo -e "${YELLOW}Removing orphaned volume: $LV (VMID: $VMID)${NC}"
        lvremove -f pve/$LV 2>/dev/null || echo "  Could not remove $LV"
    fi
done
echo -e "${GREEN}✓ Orphaned disks cleaned${NC}"
echo ""

echo -e "${YELLOW}Step 6: Cleaning LXC cache...${NC}"
rm -rf /var/lib/vz/images/* 2>/dev/null || true
rm -rf /var/lib/vz/dump/* 2>/dev/null || true
echo -e "${GREEN}✓ LXC cache cleaned${NC}"
echo ""

echo -e "${YELLOW}Step 7: Optimizing LVM thin pool...${NC}"
# Trim the thin pool to reclaim space
lvchange --refresh pve/data
echo -e "${GREEN}✓ LVM optimized${NC}"
echo ""

echo -e "${YELLOW}Step 8: Checking for new disks...${NC}"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep disk
echo ""

# Check if there's a second disk (sdb)
if lsblk | grep -q "sdb"; then
    echo -e "${GREEN}Found additional disk: /dev/sdb${NC}"
    echo -e "${YELLOW}Do you want to add it to Proxmox storage? (y/n)${NC}"
    read -r RESPONSE
    if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then
        echo "Creating physical volume..."
        pvcreate /dev/sdb
        
        echo "Extending volume group..."
        vgextend pve /dev/sdb
        
        echo "Extending data volume..."
        lvextend -l +100%FREE pve/data
        
        echo -e "${GREEN}✓ New disk added to storage${NC}"
    fi
else
    echo -e "${YELLOW}No additional disk found${NC}"
fi
echo ""

echo -e "${YELLOW}Step 9: Final storage status...${NC}"
echo ""
echo "=== Disk Usage ==="
df -h | grep -E "Filesystem|pve"
echo ""
echo "=== Volume Groups ==="
vgs
echo ""
echo "=== Logical Volumes ==="
lvs | grep -E "LV|data|root"
echo ""
echo "=== Available Space ==="
pvs
echo ""

echo "=========================================="
echo -e "${GREEN}Storage Optimization Complete!${NC}"
echo "=========================================="
echo ""
echo "Space recovered. Summary:"
du -sh /tmp /var/log /var/cache/apt 2>/dev/null || true
echo ""

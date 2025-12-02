# Proxmox PaaS - Troubleshooting Network Issues

## Problem
VMs cloned from Ubuntu cloud-init template aren't getting network connectivity. ARP shows "incomplete" entries.

## Root Cause
Proxmox 6.14 with Ubuntu 22.04 cloud images has issues with cloud-init network configuration, particularly with static IPs.

## Solutions

### Solution 1: Use Container (LXC) Instead of VMs
LXC containers are lighter and network configuration is more reliable:

```bash
# Create Ubuntu LXC template
pveam update
pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst

# Create container
pct create 200 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
    --hostname test-app \
    --memory 2048 \
    --cores 2 \
    --net0 name=eth0,bridge=vmbr0,ip=192.168.171.200/24,gw=192.168.171.2 \
    --password rootpass123 \
    --features nesting=1

pct start 200
sleep 10
pct exec 200 -- apt-get update
pct exec 200 -- apt-get install -y python3 python3-pip python3-venv git
```

### Solution 2: Fix Cloud-Init VM Template
The issue is the cloud image needs guest agent installed BEFORE becoming a template:

```bash
# Create VM from cloud image
qm create 9001 --name ubuntu-template --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0

# Import and configure disk
qm importdisk 9001 /tmp/ubuntu-22.04-cloudimg.img local-lvm
qm set 9001 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9001-disk-0
qm set 9001 --boot c --bootdisk scsi0
qm set 9001 --ide2 local-lvm:cloudinit
qm set 9001 --serial0 socket --vga serial0
qm set 9001 --ciuser root --cipassword rootpass123
qm set 9001 --nameserver 8.8.8.8
qm set 9001 --ipconfig0 ip=dhcp

# Start VM and wait for DHCP
qm start 9001
sleep 60

# Find its IP
DHCP_IP=$(qm guest cmd 9001 network-get-interfaces 2>/dev/null | jq -r '.[1]."ip-addresses"[0]."ip-address"' || \
         arp -an | grep $(qm config 9001 | grep -oP 'virtio=\K[^,]+') | awk '{print $2}' | tr -d '()')

echo "VM IP: $DHCP_IP"

# SSH in and install guest agent
ssh root@$DHCP_IP <<'EOF'
apt-get update
apt-get install -y qemu-guest-agent cloud-init
systemctl enable qemu-guest-agent
systemctl start qemu-guest-agent
# Clear cloud-init state so clones will re-run it
cloud-init clean --logs
systemctl stop qemu-guest-agent
EOF

# Stop and convert to template
qm stop 9001
sleep 10
qm template 9001
```

### Solution 3: Use DHCP + IP Reservation
Instead of cloud-init static IPs, use DHCP with MAC-based reservations:

```python
# Modified Flask API
def deploy():
    # ... existing code ...
    
    # Use DHCP instead of static IP
    run_cmd(f"qm clone {TEMPLATE_ID} {vmid} --name {app_name} --full")
    run_cmd(f"qm set {vmid} --cores 2 --memory 2048")
    # Leave ipconfig0 as dhcp from template
    run_cmd(f"qm start {vmid}")
    
    # Wait for VM to boot and get DHCP
    time.sleep(90)
    
    # Get actual IP from guest agent
    ip_output = run_cmd(f"qm guest cmd {vmid} network-get-interfaces 2>/dev/null | jq -r '.[1].\"ip-addresses\"[0].\"ip-address\"'")
    ip = ip_output if ip_output else "pending"
    
    return jsonify({...})
```

### Solution 4: Manual Post-Clone Network Fix
After cloning, manually fix the network inside the VM:

```bash
# After VM starts
qm stop 1102
qm start 1102

# Wait 30 seconds, then get console
sleep 30

# Via console or SSH if somehow accessible:
cat > /etc/netplan/50-cloud-init.yaml <<EOF
network:
  version: 2
  ethernets:
    ens18:
      addresses: [192.168.171.151/24]
      gateway4: 192.168.171.2
      nameservers:
        addresses: [8.8.8.8]
EOF

netplan apply
```

## Current Status
- Template VM 9000: Created but network not working in clones
- VM 1100: Running, no network
- VM 1102: Running, no network  
- VMs show "incomplete" ARP entries

## Recommended Next Steps
1. **Try LXC containers** (Solution 1) - fastest, most reliable
2. If you need VMs, rebuild template with guest agent pre-installed (Solution 2)
3. Test with DHCP first, then add static IPs once working

## Testing Commands
```bash
# Check VM status
qm status <vmid>

# Check if guest agent running
qm guest cmd <vmid> ping

# Check network config
qm config <vmid> | grep -E 'net0|ipconfig'

# Check from Proxmox if VM responds
ping 192.168.171.151
arp -a | grep 192.168.171.151

# View VM console
qm terminal <vmid>
# (Press Ctrl+O to exit)
```

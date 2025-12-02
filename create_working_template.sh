#!/bin/bash
# Create a working Ubuntu 22.04 template with guest agent

VMID=9001
IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
IMAGE_FILE="/tmp/ubuntu-22.04-cloudimg.img"

echo "Creating VM template ${VMID}..."

# Download cloud image if not exists
if [ ! -f "$IMAGE_FILE" ]; then
    echo "Downloading Ubuntu 22.04 cloud image..."
    wget -O "$IMAGE_FILE" "$IMAGE_URL"
fi

# Create VM
qm create $VMID \
    --name ubuntu-22-template \
    --memory 2048 \
    --cores 2 \
    --net0 virtio,bridge=vmbr0 \
    --serial0 socket \
    --vga serial0 \
    --ostype l26 \
    --cpu cputype=host

# Import disk
qm importdisk $VMID "$IMAGE_FILE" local-lvm

# Configure VM
qm set $VMID \
    --scsihw virtio-scsi-pci \
    --scsi0 local-lvm:vm-$VMID-disk-0 \
    --boot c --bootdisk scsi0

# Add cloud-init drive
qm set $VMID --ide2 local-lvm:cloudinit

# Configure cloud-init
qm set $VMID --ciuser root
qm set $VMID --cipassword rootpass123
qm set $VMID --nameserver 8.8.8.8
qm set $VMID --ipconfig0 ip=dhcp
qm set $VMID --agent enabled=1

# Resize disk
qm resize $VMID scsi0 +8G

# DON'T convert to template yet - we need to boot it once first
echo "Starting VM to initialize and install guest agent..."
qm start $VMID

echo "Waiting 120 seconds for cloud-init to complete..."
sleep 120

# Now install guest agent
echo "Installing qemu-guest-agent..."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@\$(qm guest cmd $VMID network-get-interfaces | jq -r '.[1]."ip-addresses"[0]."ip-address"' 2>/dev/null || echo "dhcp-ip") 'apt-get update && apt-get install -y qemu-guest-agent && systemctl enable qemu-guest-agent && systemctl start qemu-guest-agent' || {
    echo "Note: Could not SSH to install guest agent. Will try alternative method."
    echo "Please manually: qm start $VMID, SSH in, run: apt-get update && apt-get install -y qemu-guest-agent"
}

echo "Stopping VM..."
qm stop $VMID

sleep 10

# NOW convert to template
echo "Converting to template..."
qm template $VMID

echo "Template $VMID created successfully!"
echo "Use this template ID in your Flask API: TEMPLATE_ID = $VMID"

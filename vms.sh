#!/bin/bash
    set -euo pipefail
    
    clear
    cat << "EOF"
     ================================================
     ███████╗███████╗███╗   ██╗███████╗███████╗██╗
     ╚══███╔╝██╔════╝████╗  ██║██╔════╝██╔════╝██║
       ███╔╝ █████╗  ██╔██╗ ██║███████╗█████╗  ██║
      ███╔╝  ██╔══╝  ██║╚██╗██║╚════██║██╔══╝  ██║
     ███████╗███████╗██║ ╚████║███████║███████╗██║
     ╚══════╝╚══════╝╚═╝  ╚═══╝╚══════╝╚══════╝╚═╝
    
                POWERED BY ZenseiTech
     ================================================
EOF
    
    # =============================
    # Automatic Disk Management
    # =============================
    # Uses /tmp (291GB partition) to bypass the 15GB Home Wall
    REAL_STORAGE="/tmp/noverixcloud-data"
    LINK_PATH="$HOME/vms"
    
    mkdir -p "$REAL_STORAGE"
    
    if [ ! -L "$LINK_PATH" ]; then
        echo "[INFO] Redirecting storage to the large partition..."
        if [ -d "$LINK_PATH" ]; then
            mv "$LINK_PATH"/* "$REAL_STORAGE/" 2>/dev/null || true
            rm -rf "$LINK_PATH"
        fi
        ln -s "$REAL_STORAGE" "$LINK_PATH"
    fi
    
    VM_DIR="$LINK_PATH"
    IMG_FILE="$VM_DIR/ubuntu-cloud.img"
    SEED_FILE="$VM_DIR/seed.iso"
    MEMORY=1280000
    CPUS=125
    SSH_PORT=24
    DISK_SIZE=28000G
    
    mkdir -p "$VM_DIR"
    cd "$VM_DIR"
    
    # =============================
    # VM Image Setup
    # =============================
    if [ ! -f "$IMG_FILE" ]; then
        echo "[INFO] VM image not found, downloading and creating VM Image..."
        
        wget -q https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -O "$IMG_FILE"
        
        # Physical resize on the Host
        qemu-img resize "$IMG_FILE" "$DISK_SIZE"
    
        # Cloud-init configuration
        cat > user-data <<EOF
    #cloud-config
    hostname: root
    manage_etc_hosts: true
    disable_root: false
    ssh_pwauth: true
    chpasswd:
      list: |
        root:root
      expire: false
    
    growpart:
      mode: auto
      devices: ["/"]
    resize_rootfs: true
    
    runcmd:
      - growpart /dev/vda 1 || growpart /dev/vda 3 || true
      - resize2fs /dev/vda1 || resize2fs /dev/vda3 || true
      - sed -ri "s/^#?PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
      - systemctl restart ssh
EOF
    
        cat > meta-data <<EOF
    instance-id: iid-local01
    local-hostname: Host
EOF
    
        # Generate the config ISO (using cloud-utils from dev.nix)
        cloud-localds "$SEED_FILE" user-data meta-data
        echo "[INFO] VM setup complete!"
    else
        echo "[INFO] VM image found, launching..."
    fi
    
    # IDENTITY: AMD Ryzen 9 7900 Emulation
    CPU_EMULATION="max"
    
    # =============================
    # Start VM
    # =============================
    echo "[INFO] Starting AMD Ryzen 9 7900 VPS..."
    echo "[INFO] Storage Path: $(readlink -f $VM_DIR)"
    echo "[INFO] Access: ssh root@localhost -p $SSH_PORT (Password: root)"
    
    exec qemu-system-x86_64 \
        -m "$MEMORY" \
        -smp "$CPUS",sockets=1,cores=125,threads=2,maxcpus=125 \
        -cpu "$CPU_EMULATION" \
        -drive file="$IMG_FILE",format=qcow2,if=virtio \
        -drive file="$SEED_FILE",format=raw,if=virtio \
        -boot order=c \
        -device virtio-net-pci,netdev=n0 \
        -netdev user,id=n0,hostfwd=tcp::"$SSH_PORT"-:22 \
        -nographic -serial mon:stdio

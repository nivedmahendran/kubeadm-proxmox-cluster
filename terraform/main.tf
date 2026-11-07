locals {
  net_prefix = split("/", var.node_subnet)[1]

  # Node definitions: name -> { vmid, ip, cores, memory_mb, disk_gb }
  nodes = {
    "k8s-cp1" = { vmid = 210, ip = "10.10.10.200", cores = 2, memory = 4096, disk = 40 }
    "k8s-worker1" = { vmid = 211, ip = "10.10.10.203", cores = 2, memory = 3072, disk = 40 }
    "k8s-worker2" = { vmid = 212, ip = "10.10.10.204", cores = 2, memory = 3072, disk = 40 }
  }
}

resource "proxmox_virtual_environment_vm" "node" {
  for_each = local.nodes

  name      = each.key
  node_name = "pve"
  vm_id     = each.value.vmid

  agent {
    enabled = true
    wait_for_ip {
      disabled = true
    }
  }

  bios   = "ovmf"
  machine = "q35"

  efi_disk {
    datastore_id = "local-lvm"
    type          = "4m"
    pre_enrolled_keys = false
  }

  serial_device {}

  cpu {
    cores = each.value.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = each.value.memory
    floating  = each.value.memory
  }

  clone {
    vm_id = var.template_vmid
    full  = true
  }

  disk {
    datastore_id = "local-lvm"
    interface     = "virtio0"
    size         = each.value.disk
  }

  network_device {
    bridge = "vmbr0"
  }

  initialization {
    datastore_id = "local-lvm"
    interface     = "ide2"
    type         = "nocloud"

    ip_config {
      ipv4 {
        address = "${each.value.ip}/${local.net_prefix}"
        gateway = var.gateway
      }
    }

    dns {
      servers = var.nameservers
    }

    user_account {
      username = var.ci_user
      keys     = [var.ssh_public_key]
    }
  }

  operating_system {
    type = "l26"
  }

  tags = ["kubeadm", "k8s", "homelab"]
}

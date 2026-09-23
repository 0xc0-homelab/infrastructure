# A VM cloned from a template, configured by cloud-init through the Proxmox API
# only: user, SSH keys, address. Everything inside the guest after that is
# Ansible's job.

resource "proxmox_virtual_environment_vm" "main" {
  name      = var.name
  vm_id     = var.vm_id
  node_name = var.node_name
  tags      = sort(distinct(concat(["opentofu"], var.tags)))

  started = true
  on_boot = true

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  operating_system {
    type = "l26"
  }

  cpu {
    cores = var.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.memory_mb
  }

  # The image ships no guest agent; Ansible installs it, then this goes true.
  agent {
    enabled = false
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.disk_size_gb
    discard      = "on"
    iothread     = true
  }

  # firewall = true: zone rules only apply to a NIC with the firewall on.
  network_device {
    bridge   = var.vnet
    model    = "virtio"
    firewall = true
  }

  serial_device {}

  initialization {
    datastore_id = var.datastore_id

    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      username = var.username
      keys     = var.ssh_public_keys
    }
  }
}

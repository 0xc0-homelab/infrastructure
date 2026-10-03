resource "terraform_data" "rebuild" {
  input = var.rebuild
}

# No vm_id: Proxmox assigns the next free one.
resource "proxmox_virtual_environment_vm" "main" {
  name      = var.name
  node_name = var.node_name
  tags      = sort(distinct(concat(["opentofu"], var.tags)))

  started = true
  on_boot = true

  # One apply could restart the CI VMs running it, both connectors or etcd's
  # quorum at once: scripts/rolling-reboot restarts them one at a time.
  reboot_after_update = false

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  operating_system {
    type = "l26"
  }

  cpu {
    cores = var.cores
    type  = var.cpu_type
  }

  # A balloon device with no target: Proxmox sees the guest's real memory use
  # instead of its footprint, full of cache.
  memory {
    dedicated = var.memory_mb
    floating  = var.memory_mb
  }

  agent {
    enabled = true
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.disk_size_gb
    discard      = "on"
    iothread     = true
  }

  # They live and die with the VM, so prevent_destroy covers them.
  dynamic "disk" {
    for_each = var.data_disks_gb
    content {
      datastore_id = var.datastore_id
      interface    = "scsi${disk.key + 1}"
      size         = disk.value
      discard      = "on"
      iothread     = true
    }
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

  lifecycle {
    # Only a literal is allowed: a deliberate rebuild lifts it in that PR, and
    # the next PR sets it back.
    prevent_destroy = true

    replace_triggered_by = [terraform_data.rebuild]
    # A new template must not recreate every VM cloned from it. cloud-init
    # applies the user only on first boot; the base role keeps the keys.
    ignore_changes = [clone, initialization[0].user_account]
  }
}

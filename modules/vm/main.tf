# A VM cloned from a template, configured by cloud-init through the Proxmox API
# only: user, SSH keys, address. Everything inside the guest after that is
# Ansible's job.

# Holds the rebuild counter: the VM is replaced when it changes.
resource "terraform_data" "rebuild" {
  input = var.rebuild
}

# No vm_id: Proxmox assigns the next free one, from 100, and it stays in the
# state. Nobody picks VMIDs.
resource "proxmox_virtual_environment_vm" "main" {
  name      = var.name
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


  # The baked templates ship the guest agent. Switching it on for an existing
  # VM reboots it, so the flag is per VM while each one is rebuilt.
  agent {
    enabled = var.guest_agent
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

  lifecycle {
    # No VM is destroyed as a matter of course: any plan that deletes or
    # replaces one fails, in CI and from the laptop alike. OpenTofu takes it
    # only as a literal, so it covers every VM. A deliberate rebuild or removal
    # lifts it in that same PR, and the next PR sets it back.
    prevent_destroy = true

    replace_triggered_by = [terraform_data.rebuild]
    # A template only matters when the VM is created: a newer one, or one
    # rebuilt under a new VMID, must not recreate every VM cloned from it.
    # Moving a VM onto the new template is bumping its rebuild.
    ignore_changes = [clone]
  }
}

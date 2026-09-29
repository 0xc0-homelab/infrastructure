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

  # An apply never restarts a VM on its own: a change that needs one stays
  # pending, and the VMs are restarted one at a time with
  # scripts/rolling-reboot. Otherwise one apply could restart the CI VMs
  # running it, both vm-access connectors, or etcd's whole quorum at once.
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

  memory {
    dedicated = var.memory_mb
  }

  # The templates are baked with the guest agent: the provider waits for it
  # when the VM is created.
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

  # Blank data disks, scsi1 onwards, left unformatted: what uses them sets
  # them up. They live and die with the VM, so prevent_destroy covers them.
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
    # No VM is destroyed as a matter of course: any plan that deletes or
    # replaces one fails, in CI and from the laptop alike. OpenTofu takes it
    # only as a literal, so it covers every VM. A deliberate rebuild or removal
    # lifts it in that same PR, and the next PR sets it back.
    prevent_destroy = true

    replace_triggered_by = [terraform_data.rebuild]
    # A template only matters when the VM is created: a newer one, or one
    # rebuilt under a new VMID, must not recreate every VM cloned from it.
    # Moving a VM onto the new template is bumping its rebuild.
    #
    # The user and its keys, likewise: cloud-init applies them on a VM's first
    # boot only, so a change later would never reach the guest, and updating a
    # running VM's cloud-init drive may reboot it. The base role keeps the keys
    # on every VM that exists.
    ignore_changes = [clone, initialization[0].user_account]
  }
}

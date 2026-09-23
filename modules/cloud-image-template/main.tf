# A VM template built straight from a distribution's cloud image, entirely
# through the Proxmox API — no SSH to the node, no build VM. The image is
# downloaded and checked by Proxmox itself, then imported as the template disk.
# Per-VM settings (user, SSH key, address) come from cloud-init on each clone.

resource "proxmox_download_file" "main" {
  node_name          = var.node_name
  datastore_id       = var.datastore_id
  content_type       = "import"
  url                = var.image_url
  checksum           = var.image_checksum
  checksum_algorithm = "sha512"
}

resource "proxmox_virtual_environment_vm" "main" {
  name        = var.name
  vm_id       = var.vm_id
  node_name   = var.node_name
  description = "Built by OpenTofu from ${var.image_url}"
  tags        = ["opentofu", "template"]

  template = true
  started  = false

  operating_system {
    type = "l26"
  }

  cpu {
    cores = 1
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 1024
  }

  # The cloud image ships no guest agent. It is installed on each VM after
  # first boot, and enabled here once that is in place.
  agent {
    enabled = false
  }

  scsi_hardware = "virtio-scsi-single"

  disk {
    datastore_id = var.datastore_id
    import_from  = proxmox_download_file.main.id
    interface    = "scsi0"
    size         = var.disk_size_gb
    discard      = "on"
    iothread     = true
  }

  network_device {
    bridge = var.bridge
    model  = "virtio"
  }

  # Debian and Ubuntu cloud images log to the serial console.
  serial_device {}

  # The cloud-init drive; each clone fills in its own user, key and address.
  initialization {
    datastore_id = var.datastore_id
  }
}

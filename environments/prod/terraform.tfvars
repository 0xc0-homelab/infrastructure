# Data for this environment. Secrets come from the environment, never from here.

nodes = ["pve-1"]

sdn_zone_id = "homelab"

# Mirrors the zones block of docs/zones.md, which is normative: change that
# file first. Keys are VNet IDs (Proxmox: up to 8 letters and digits), so
# workloads is wklds; alias carries the full name.
zones = {
  mgmt = {
    alias = "mgmt"
    cidr  = "10.10.0.0/24"
    snat  = true
  }
  ci = {
    alias = "ci"
    cidr  = "10.10.1.0/24"
    snat  = true
  }
  platform = {
    alias = "platform"
    cidr  = "10.10.4.0/24"
    snat  = true
  }
  edge = {
    alias = "edge"
    cidr  = "10.10.8.0/24"
    snat  = true
  }
  wklds = {
    alias = "workloads"
    cidr  = "10.10.16.0/20"
    snat  = true
  }
  data = {
    alias = "data"
    cidr  = "10.10.32.0/24"
    snat  = false
  }
}

template_datastore = "local"

# Official Debian cloud images, pinned to a dated build with the SHA-512 Debian
# publishes next to it (SHA512SUMS). Bumping the image is its own commit.
templates = {
  "debian-13-base" = {
    vm_id          = 9000
    image_url      = "https://cloud.debian.org/images/cloud/trixie/20260914-2601/debian-13-genericcloud-amd64-20260914-2601.qcow2"
    image_checksum = "95e110dfcdbd0ed8a82a75ed9579802f9950cabf51a810dcc6388e81bc778188713878b9f28d583a0ea602fbf48b35996ae9ad37f584166d8fbd6489df248f53"
    bridge         = "mgmt"
  }
}

cloudflare_account_id = "ca1599ae7852d5b4718cba351adad927"
zero_trust_team       = "0xc0"
homelab_network       = "10.10.0.0/16"

vm_admin_user     = "ops"
vm_admin_ssh_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO0Sq1ydjDPRC82QwtxDWSxk2ci/E2bChEJCwm665nzZ sergioaten@0xc0-homelab 2026-09-22"]
vm_dns_servers    = ["1.1.1.1", "1.0.0.1"]

# Mirrors the vms block of docs/zones.md. Only phase 1 VMs.
vms = {
  "vm-access" = {
    vm_id     = 100
    template  = "debian-13-base"
    vnet      = "mgmt"
    ip        = "10.10.0.10"
    cores     = 1
    memory_mb = 1024
  }
  # Second connector of the same tunnel, for HA: one can be rebuilt while the
  # other keeps admin access.
  "vm-access-02" = {
    vm_id     = 101
    template  = "debian-13-base"
    vnet      = "mgmt"
    ip        = "10.10.0.20"
    cores     = 1
    memory_mb = 1024
  }
}

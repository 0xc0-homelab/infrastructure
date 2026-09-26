# Data for this environment. Secrets come from the environment, never from here.

nodes = ["pve-1"]

sdn_zone_id = "homelab"

# The homelab zones, explained in docs/zones.md. Keys are VNet IDs (Proxmox: up to 8 letters and digits), so
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
  # Raw: no VM clones it. Packer bakes debian-13-base from it.
  "debian-13-cloud" = {
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

# The VMs that exist. The addressing plan, later phases included, is in
# docs/zones.md.
vms = {
  "vm-access-01" = {
    rebuild   = 1
    template  = "debian-13-base"
    vnet      = "mgmt"
    ip        = "10.10.0.10"
    cores     = 1
    memory_mb = 1024
  }
  # Second connector of the same tunnel, for HA: one can be rebuilt while the
  # other keeps admin access.
  "vm-access-02" = {
    rebuild   = 2
    template  = "debian-13-base"
    vnet      = "mgmt"
    ip        = "10.10.0.20"
    cores     = 1
    memory_mb = 1024
  }
  # The self-hosted GitHub Actions runners. The disk holds the runner, the
  # tools mise installs per job and the providers.
  "vm-ci" = {
    # Its apply runs from the laptop: in CI it would destroy the runner it
    # runs on.
    rebuild      = 1
    template     = "debian-13-runner"
    vnet         = "ci"
    ip           = "10.10.1.10"
    cores        = 2
    memory_mb    = 4096
    disk_size_gb = 32
  }
}

# Enforces every VM's firewall. Needs Docker on the node with
# `ip-forward-no-drop` (docs/architecture.md, The node).
datacenter_firewall_enabled = true

# The node's DROP. Admin access to the node is then only over WARP, to
# 10.10.0.1, and the Hetzner Rescue system is the way back in.
node_firewall_enabled = true

# Traefik on the node, outside IaC. WARP devices resolve these to 10.10.0.1.
node_web_hostnames = ["pve.0xc0.cc", "pbs.0xc0.cc", "s3.0xc0.cc", "s3-console.0xc0.cc"]

# The transit matrix: every flow the firewall allows. Anything not here is
# denied. Every port is TCP. `from` and `to` are zone names (the `alias` of a
# zone above), `node`, or `internet`; an empty `to` means the zone initiates
# nothing. The zone-firewall module turns each entry into rules whose comment
# is "<from> -> <to>: <note>". Notes are plain ASCII: Proxmox keeps them as is.
transit = [
  { from = "mgmt", to = ["ci", "platform", "edge", "workloads", "data", "node"], ports = [22, 3389, 6443, 8006, 8200], note = "admin access, arrives through the vm-access tunnel" },
  { from = "ci", to = ["edge", "platform", "workloads", "data"], ports = [22], note = "deploy over SSH from the runner" },
  { from = "ci", to = ["node"], ports = [443, 8006], note = "Proxmox API and RustFS, through Traefik on 443. NEVER 22 towards the node from ci" },
  { from = "ci", to = ["platform"], ports = [8200], note = "Vault, from phase 3 onwards" },
  { from = "edge", to = ["workloads"], ports = [8080, "30000-32767"], note = "NGINX towards apps and towards the cluster ingress" },
  { from = "workloads", to = ["data"], ports = [5432, 6379] },
  { from = "workloads", to = ["platform"], ports = [8200] },
  { from = "platform", to = ["workloads", "data", "node"], ports = [9100, 10250], note = "Prometheus scrape" },
  { from = "platform", to = ["internet"], ports = [443], note = "alerts to the phone" },
  { from = "data", to = [], ports = [], note = "data does NOT initiate connections. Explicit egress deny rule." },
  { from = "mgmt", to = ["node"], ports = [443], note = "Traefik on the host (Proxmox UI, PBS, RustFS), over WARP; never from the internet" },
  { from = "internet", to = ["node"], ports = [22], note = "break-glass SSH, key-only; the Hetzner firewall keeps it closed until opened" },
  { from = "mgmt", to = ["mgmt"], ports = [22], note = "between the vm-access connectors; a WARP session can leave from either one" },
]

# The node is the router, on DROP. From the admin zones it admits only these
# ports, whatever else an entry opens towards the zones; from anywhere else, an
# entry's ports as written.
node_firewall = {
  admin_zones = ["mgmt", "ci"]
  admin_ports = [22, 443, 8006]
}

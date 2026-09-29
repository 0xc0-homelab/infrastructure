# Data for this environment. Secrets come from the environment, never from here.

nodes = ["pve-1"]

sdn_zone_id = "homelab"

# The homelab zones, explained in docs/zones.md. Keys are VNet IDs (Proxmox: up
# to 8 letters and digits); alias is the name everything else uses.
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
}

template_datastore = "local"

# Official Debian cloud images, pinned to a dated build with the SHA-512 Debian
# publishes next to it (SHA512SUMS). Bumping the image is its own commit.
templates = {
  # Raw: no VM clones it. Packer bakes debian-13-base from it.
  "debian-13-cloud" = {
    vm_id          = 9000
    image_url      = "https://cloud.debian.org/images/cloud/trixie/20260914-2601/debian-13-genericcloud-amd64-20260914-2601.qcow2"
    image_checksum = "95e110dfcdbd0ed8a82a75ed9579802f9950cabf51a810dcc6388e81bc778188713878b9f28d583a0ea602fbf48b35996ae9ad37f584166d8fbd6489df248f53"
    bridge         = "mgmt"
  }
  # Raw: no VM clones it. Packer bakes rocky-10-base from it, for the RKE2
  # nodes. Rocky publishes only SHA-256.
  "rocky-10-cloud" = {
    vm_id              = 9001
    image_url          = "https://dl.rockylinux.org/pub/rocky/10/images/x86_64/Rocky-10-GenericCloud-Base-10.2-20260525.0.x86_64.qcow2"
    image_checksum     = "9fc9e9ff16888bb68ac39b0392e25c9c92684d50c85f1cce6ab549363bbc4b48"
    checksum_algorithm = "sha256"
    # The image's virtual size is 10 GiB, and Proxmox never shrinks a disk.
    disk_size_gb = 10
    bridge       = "mgmt"
  }
}

cloudflare_account_id = "ca1599ae7852d5b4718cba351adad927"
zero_trust_team       = "0xc0"
homelab_network       = "10.10.0.0/16"

vm_admin_user = "ops"
# The operator's key, and CI's, whose private half is in
# secrets/ansible.sops.yaml: the pipeline runs every playbook. cloud-init sets
# them on a new VM; the base role keeps them on every VM.
vm_admin_ssh_keys = [
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO0Sq1ydjDPRC82QwtxDWSxk2ci/E2bChEJCwm665nzZ sergioaten@0xc0-homelab 2026-09-22",
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBfmJpvE1msYS0+VYbfP2M8y0+w2DzuA7LLe5k8GvSlP ci@0xc0-homelab 2026-09-29",
]
vm_dns_servers = ["1.1.1.1", "1.0.0.1"]

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
  # The self-hosted GitHub Actions runners, two identical VMs: CI keeps running
  # while one is down, and a job on one can rebuild the other. The disk holds
  # the runner, the tools mise installs per job and the providers.
  "vm-ci-01" = {
    rebuild      = 1
    template     = "debian-13-runner"
    vnet         = "ci"
    ip           = "10.10.1.10"
    cores        = 2
    memory_mb    = 4096
    disk_size_gb = 32
  }
  "vm-ci-02" = {
    template     = "debian-13-runner"
    vnet         = "ci"
    ip           = "10.10.1.20"
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
# denied. `proto` is tcp unless stated; an entry for a protocol without ports
# (vrrp) has none. `from` and `to` are zone names (the `alias` of a
# zone above), `node`, or `internet`; an empty `to` means the zone initiates
# nothing. The zone-firewall module turns each entry into rules whose comment
# is "<from> -> <to>: <note>". Notes are plain ASCII: Proxmox keeps them as is.
# The RKE2 cluster and its load balancer, in platform (docs/zones.md). The
# three servers are identical: control plane, etcd and workloads on each.
cluster = {
  vnet = "platform"
  # keepalived's, in front of HAProxy; no VM takes it.
  vip = "10.10.4.10"
  load_balancers = {
    template = "debian-13-base"
    nodes = {
      "vm-lb-01" = { ip = "10.10.4.11" }
      "vm-lb-02" = { ip = "10.10.4.12" }
    }
  }
  servers = {
    template = "rocky-10-base"
    # The system disk holds RKE2, etcd, the images and the logs; the two blank
    # ones are Longhorn's, joined by LVM (the longhorn_node role).
    disk_size_gb  = 50
    data_disks_gb = [100, 100]
    nodes = {
      # Rebuilt with the smaller system disk (#120).
      "vm-rke2-01" = { ip = "10.10.4.21", rebuild = 1 }
      "vm-rke2-02" = { ip = "10.10.4.22", rebuild = 1 }
      "vm-rke2-03" = { ip = "10.10.4.23", rebuild = 1 }
    }
  }
}

transit = [
  { from = "mgmt", to = ["mgmt"], ports = [22], note = "between the vm-access connectors; a WARP session can leave from either one" },
  { from = "mgmt", to = ["ci"], ports = [22], note = "admin SSH, through the vm-access tunnel" },
  { from = "mgmt", to = ["platform"], ports = [22, 80, 6443, 8200], note = "admin: SSH, the internal portals through the LB over WARP, the Kubernetes API, Vault" },
  { from = "mgmt", to = ["node"], ports = [22, 8006], note = "admin: SSH and the Proxmox API, through the vm-access tunnel" },
  { from = "mgmt", to = ["node"], ports = [443], note = "Traefik on the host (Proxmox UI, PBS, RustFS), over WARP; never from the internet" },
  { from = "ci", to = ["platform"], ports = [22, 6443], note = "the runner: SSH to configure the VMs, and the Kubernetes API" },
  # The one way into mgmt from another zone (operator decision, 2026-09-29):
  # the pipeline runs the vm-access playbook. Only the CI VMs, not the zone.
  { from = "ci", to = ["mgmt"], ports = [22], sources = ["vm-ci-01", "vm-ci-02"], note = "the pipeline's playbooks, from the CI VMs only" },
  # A job on either CI VM configures both.
  { from = "ci", to = ["ci"], ports = [22], sources = ["vm-ci-01", "vm-ci-02"], note = "the pipeline's playbooks, between the CI VMs" },
  { from = "ci", to = ["node"], ports = [443, 8006], note = "Proxmox API and RustFS, through Traefik on 443. NEVER 22 towards the node from ci" },
  { from = "platform", to = ["platform"], ports = ["2379-2381", 6443, 9099, 9345, 10250, "30000-32767"], note = "the cluster: etcd, API, Canal health, supervisor, kubelet, NodePorts; the LB towards the nodes" },
  { from = "platform", to = ["platform"], proto = "udp", ports = [8472], note = "Canal VXLAN between the cluster nodes" },
  { from = "platform", to = ["platform"], proto = "vrrp", ports = [], note = "keepalived between the two LB VMs" },
  { from = "platform", to = ["node"], ports = [9100], note = "node metrics" },
  { from = "platform", to = ["internet"], ports = [443], note = "egress, alerts to the phone among it" },
  { from = "internet", to = ["node"], ports = [22], note = "break-glass SSH, key-only; the Hetzner firewall keeps it closed until opened" },
]

# The node is the router, on DROP. From the admin zones it admits only these
# ports, whatever else an entry opens towards the zones; from anywhere else, an
# entry's ports as written.
node_firewall = {
  admin_zones = ["mgmt", "ci"]
  admin_ports = [22, 443, 8006]
}

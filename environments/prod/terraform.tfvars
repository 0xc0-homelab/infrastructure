# Secrets come from the environment, never from here.

nodes = ["pve-1"]

sdn_zone_id = "homelab"

# The zones, explained in docs/zones.md. Keys are VNet IDs (Proxmox: up
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

# Pinned to a dated build, with the checksum the distribution publishes.
templates = {
  "debian-13-cloud" = {
    vm_id          = 9000
    image_url      = "https://cloud.debian.org/images/cloud/trixie/20260914-2601/debian-13-genericcloud-amd64-20260914-2601.qcow2"
    image_checksum = "95e110dfcdbd0ed8a82a75ed9579802f9950cabf51a810dcc6388e81bc778188713878b9f28d583a0ea602fbf48b35996ae9ad37f584166d8fbd6489df248f53"
    bridge         = "mgmt"
  }
  # Rocky publishes only SHA-256.
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
# The operator's and CI's (private half in Vault, ci/infrastructure/ssh).
vm_admin_ssh_keys = [
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO0Sq1ydjDPRC82QwtxDWSxk2ci/E2bChEJCwm665nzZ sergioaten@0xc0-homelab 2026-09-22",
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBfmJpvE1msYS0+VYbfP2M8y0+w2DzuA7LLe5k8GvSlP ci@0xc0-homelab 2026-09-29",
]
vm_dns_servers = ["1.1.1.1", "1.0.0.1"]

# The VMs outside the cluster. The addressing plan is in docs/zones.md.
vms = {
  "vm-access-01" = {
    rebuild   = 1
    template  = "debian-13-base"
    vnet      = "mgmt"
    ip        = "10.10.0.10"
    cores     = 1
    memory_mb = 1024
  }
  # One connector can be rebuilt while the other keeps admin access.
  "vm-access-02" = {
    rebuild   = 2
    template  = "debian-13-base"
    vnet      = "mgmt"
    ip        = "10.10.0.20"
    cores     = 1
    memory_mb = 1024
  }
  # Two, so a job on one can rebuild the other.
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

# The Hetzner Rescue system is the way back in.
node_firewall_enabled = true

# Traefik on the node, outside IaC.
node_web_hostnames = ["pve.0xc0.cc", "pbs.0xc0.cc", "s3.0xc0.cc", "s3-console.0xc0.cc"]

cluster = {
  vnet = "platform"
  # keepalived's; no VM takes it.
  vip = "10.10.4.10"
  # The WARP-only path (operator decision, 2026-09-30): the public tunnel
  # never comes here.
  internal_vip = "10.10.4.9"
  load_balancers = {
    template = "debian-13-base"
    nodes = {
      "vm-lb-01" = { ip = "10.10.4.11" }
      "vm-lb-02" = { ip = "10.10.4.12" }
    }
  }
  servers = {
    template = "rocky-10-base"
    # The data disks are Longhorn's, joined by LVM (the longhorn_node role).
    disk_size_gb  = 50
    data_disks_gb = [100, 100]
    nodes = {
      "vm-rke2-01" = { ip = "10.10.4.21", rebuild = 1 }
      "vm-rke2-02" = { ip = "10.10.4.22", rebuild = 1 }
      "vm-rke2-03" = { ip = "10.10.4.23", rebuild = 1 }
    }
  }
  # Workers only (operator decision, 2026-09-30): etcd stays with the servers.
  agents = {
    template      = "rocky-10-base"
    disk_size_gb  = 50
    data_disks_gb = [100, 100]
    nodes = {
      "vm-rke2-04" = { ip = "10.10.4.24" }
    }
  }
}

# Every flow the firewall allows (docs/zones.md). An empty `to` means the zone
# initiates nothing. Notes become rule comments, plain ASCII.
transit = [
  { from = "mgmt", to = ["mgmt"], ports = [22], note = "between the vm-access connectors; a WARP session can leave from either one" },
  { from = "mgmt", to = ["ci"], ports = [22], note = "admin SSH, through the vm-access tunnel" },
  { from = "mgmt", to = ["platform"], ports = [22, 80, 443, 6443, 8200], note = "admin: SSH, both VIPs over WARP (443; 80 only redirects, on the public one), the Kubernetes API, Vault" },
  { from = "mgmt", to = ["node"], ports = [22, 8006], note = "admin: SSH and the Proxmox API, through the vm-access tunnel" },
  { from = "mgmt", to = ["node"], ports = [443], note = "Traefik on the host (Proxmox UI, PBS, RustFS), over WARP; never from the internet" },
  { from = "ci", to = ["platform"], ports = [22, 443, 6443], note = "the runner: SSH to configure the VMs, Vault on the internal VIP, and the Kubernetes API" },
  # The one way into mgmt from another zone (operator decision, 2026-09-29).
  { from = "ci", to = ["mgmt"], ports = [22], sources = ["vm-ci-01", "vm-ci-02"], note = "the pipeline's playbooks, from the CI VMs only" },
  { from = "ci", to = ["ci"], ports = [22], sources = ["vm-ci-01", "vm-ci-02"], note = "the pipeline's playbooks, between the CI VMs" },
  { from = "ci", to = ["node"], ports = [443, 8006], note = "Proxmox API and RustFS, through Traefik on 443. NEVER 22 towards the node from ci" },
  { from = "platform", to = ["platform"], ports = ["2379-2381", 6443, 9099, 9345, 10250, 10257, 10259, "30000-32767"], note = "the cluster: etcd and its metrics, API, Canal health, supervisor, kubelet, controller-manager and scheduler metrics, NodePorts; the LB towards the nodes" },
  { from = "platform", to = ["platform"], proto = "udp", ports = [8472], note = "Canal VXLAN between the cluster nodes" },
  { from = "platform", to = ["platform"], proto = "vrrp", ports = [], note = "keepalived between the two LB VMs" },
  { from = "platform", to = ["node"], ports = [9100], note = "node metrics" },
  { from = "platform", to = ["internet"], ports = [443], note = "egress, alerts to the phone among it" },
  { from = "internet", to = ["node"], ports = [22], note = "break-glass SSH, key-only; the Hetzner firewall keeps it closed until opened" },
]

# From the admin zones the node admits only these ports, whatever an entry
# opens.
node_firewall = {
  admin_zones = ["mgmt", "ci"]
  admin_ports = [22, 443, 8006]
}

# Every VM, to PBS on the Storage Box (operator decision, 2026-09-29).
backup = {
  storage  = "sbox"
  schedule = "03:00"
  retention = {
    daily   = 7
    weekly  = 4
    monthly = 6
  }
}

# Operator decision, 2026-09-29. Both zones are in the tunnel's own account.
public_domains = ["0xc0.cc", "offby1.cc"]

# The WARP-only path's names (operator decision, 2026-09-30).
internal_domains = ["int.0xc0.cc"]

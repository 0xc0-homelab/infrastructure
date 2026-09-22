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

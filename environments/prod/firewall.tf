# GENERATED from docs/zones.md by scripts/generate-firewall - do not edit by hand.
# To change a rule: edit the transit block of docs/zones.md and regenerate.
# Internet-bound entries (t09) are egress, allowed by the
# outbound policy of every zone but those in zone_firewall_no_egress.

locals {
  # Inbound rules per zone, keyed by VNet. All TCP.
  zone_firewall_rules = {
    ci = [
      { source = "10.10.0.0/24", dport = "22,3389,6443,8006,8200", comment = "t01: admin access, arrives through the vm-access tunnel" },
    ]
    data = [
      { source = "10.10.0.0/24", dport = "22,3389,6443,8006,8200", comment = "t01: admin access, arrives through the vm-access tunnel" },
      { source = "10.10.1.0/24", dport = "22", comment = "t02: deploy over SSH from the runner" },
      { source = "10.10.16.0/20", dport = "5432,6379", comment = "t06" },
      { source = "10.10.4.0/24", dport = "9100,10250", comment = "t08: Prometheus scrape" },
    ]
    edge = [
      { source = "10.10.0.0/24", dport = "22,3389,6443,8006,8200", comment = "t01: admin access, arrives through the vm-access tunnel" },
      { source = "10.10.1.0/24", dport = "22", comment = "t02: deploy over SSH from the runner" },
    ]
    mgmt = [
      { source = "10.10.0.0/24", dport = "22", comment = "t12: between the vm-access connectors; a WARP session can leave from either one" },
    ]
    platform = [
      { source = "10.10.0.0/24", dport = "22,3389,6443,8006,8200", comment = "t01: admin access, arrives through the vm-access tunnel" },
      { source = "10.10.1.0/24", dport = "22", comment = "t02: deploy over SSH from the runner" },
      { source = "10.10.1.0/24", dport = "8200", comment = "t04: Vault, from phase 3 onwards" },
      { source = "10.10.16.0/20", dport = "8200", comment = "t07" },
    ]
    wklds = [
      { source = "10.10.0.0/24", dport = "22,3389,6443,8006,8200", comment = "t01: admin access, arrives through the vm-access tunnel" },
      { source = "10.10.1.0/24", dport = "22", comment = "t02: deploy over SSH from the runner" },
      { source = "10.10.8.0/24", dport = "8080,30000:32767", comment = "t05: NGINX towards apps and towards the cluster ingress" },
      { source = "10.10.4.0/24", dport = "9100,10250", comment = "t08: Prometheus scrape" },
    ]
  }

  # Zones that initiate nothing: their VMs get an outbound DROP policy.
  zone_firewall_no_egress = ["data"]

  # Inbound rules of the node itself. All TCP; an empty source is any.
  node_firewall_rules = [
    { source = "10.10.0.0/24", dport = "22,8006", comment = "t01: admin access, arrives through the vm-access tunnel" },
    { source = "10.10.1.0/24", dport = "443,8006", comment = "t03: Proxmox API and RustFS, through Traefik on 443. NEVER 22 towards the node from ci" },
    { source = "10.10.4.0/24", dport = "9100,10250", comment = "t08: Prometheus scrape" },
    { source = "10.10.0.0/24", dport = "443", comment = "t11: Traefik on the host (Proxmox UI, PBS, RustFS), over WARP. Closed to the internet since the CI runner exists" },
  ]
}

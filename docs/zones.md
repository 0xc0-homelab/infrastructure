# Zones — network source of truth

This document is **normative**. `firewall.tf` is generated from the `transit`
block below; it is never hand-edited. Changing a port means editing this file
and regenerating (skill `firewall-matrix`).

## Zones

Each zone is a VNet in one Proxmox SDN Simple zone (`homelab`), with a subnet
whose gateway is the host (`gw`) and SNAT for egress through `eno1` — except
`data`, which initiates nothing and gets no SNAT. `vnet` is the VNet ID in
Proxmox, limited to 8 letters and digits; `environments/prod/terraform.tfvars`
mirrors this block.

```yaml
zones:
  mgmt:      { cidr: 10.10.0.0/24,  gw: 10.10.0.1,  group: control,   vnet: mgmt }
  ci:        { cidr: 10.10.1.0/24,  gw: 10.10.1.1,  group: control,   vnet: ci }
  platform:  { cidr: 10.10.4.0/24,  gw: 10.10.4.1,  group: platform,  vnet: platform }
  edge:      { cidr: 10.10.8.0/24,  gw: 10.10.8.1,  group: exposed,   vnet: edge }
  workloads: { cidr: 10.10.16.0/20, gw: 10.10.16.1, group: workloads, vnet: wklds }
  data:      { cidr: 10.10.32.0/24, gw: 10.10.32.1, group: data,      vnet: data }

# Control aggregate: mgmt + ci. The only source allowed towards the node.
aggregates:
  control: 10.10.0.0/22

# The host/hypervisor. DROP policy. Not a zone: it is the router.
node:
  role: router+firewall
  policy: DROP
  ingress_allowed_from: control
  ingress_ports: [22, 8006]
  # Plus every transit entry whose `to` includes `node` — today t11, 443 from
  # the internet for Traefik.
```

## Reserved ranges

No zone, VM or service may use these ranges. **Always** check before proposing
a new IP.

```yaml
reserved:
  10.11.0.0/16:   node 2 (phase 5)
  10.20.0.0/16:   Hetzner Cloud and vSwitch (phase 4)
  10.42.0.0/16:   RKE2 pods (phase 6)
  10.43.0.0/16:   RKE2 services (phase 6)
  10.66.66.0/24:  future lab
```

## Machines

```yaml
vms:
  vm-access:   { zone: mgmt,      ip: 10.10.0.10,  vcpu: 1, ram_gb: 1,  phase: 1 }
  vm-edge:     { zone: edge,      ip: 10.10.8.10,  vcpu: 2, ram_gb: 4,  phase: 1 }
  vm-ci:       { zone: ci,        ip: 10.10.1.10,  vcpu: 2, ram_gb: 4,  phase: 2 }
  vm-apps:     { zone: workloads, ip: 10.10.16.10, vcpu: 4, ram_gb: 12, phase: 2 }
  vm-data:     { zone: data,      ip: 10.10.32.10, vcpu: 2, ram_gb: 8,  phase: 2 }
  vm-vault:    { zone: platform,  ip: 10.10.4.10,  vcpu: 1, ram_gb: 2,  phase: 3 }
  vm-platform: { zone: platform,  ip: 10.10.4.20,  vcpu: 4, ram_gb: 8,  phase: 3 }
  vm-rke2:     { zone: workloads, ip: 10.10.16.20, vcpu: 4, ram_gb: 12, phase: 6 }
```

## Transit matrix

Anything not listed here is denied. Every rule in `firewall.tf` must trace back
to a line of this block through its `id`.

```yaml
transit:
  - id: t01
    from: mgmt
    to:   [ci, platform, edge, workloads, data, node]
    ports: [22, 3389, 6443, 8006, 8200]
    note: admin access, arrives through the vm-access tunnel

  - id: t02
    from: ci
    to:   [edge, platform, workloads, data]
    ports: [22]
    note: deploy over SSH from the runner

  - id: t03
    from: ci
    to:   [node]
    ports: [8006]
    note: Proxmox API. NEVER 22 towards the node from ci

  - id: t04
    from: ci
    to:   [platform]
    ports: [8200]
    note: Vault, from phase 3 onwards

  - id: t05
    from: edge
    to:   [workloads]
    ports: [8080, 30000-32767]
    note: NGINX towards apps and towards the cluster ingress

  - id: t06
    from: workloads
    to:   [data]
    ports: [5432, 6379]

  - id: t07
    from: workloads
    to:   [platform]
    ports: [8200]

  - id: t08
    from: platform
    to:   [workloads, data, node]
    ports: [9100, 10250]
    note: Prometheus scrape

  - id: t09
    from: platform
    to:   [internet]
    ports: [443]
    note: alerts to the phone

  - id: t10
    from: data
    to:   []
    ports: []
    note: data does NOT initiate connections. Explicit egress deny rule.

  - id: t11
    from: internet
    to:   [node]
    ports: [443]
    note: Traefik on the host (Proxmox UI, PBS, RustFS). Open to the internet until the CI runner exists — 0xc0-homelab/.github#13
```

## Invariants

Checked by the `homelab:network-reviewer` agent before every PR.

1. Every IP falls inside the supernet of its zone and none lands on a reserved
   range.
2. No duplicate IPs.
3. Every rule in `firewall.tf` traces to an `id` of the matrix. A rule with no
   backing is a **critical** finding.
4. Zero egress rules from `data`.
5. Zero ingress rules towards `mgmt` from any zone.
6. The node stays on DROP, with only 22 and 8006 from `10.10.0.0/22`, plus
   443 from the internet through `t11`. Any other ingress to the node is a
   **critical** finding.
7. No admin dashboard published through `vm-edge`: private ones go through the
   `vm-access` tunnel.
8. No VM from a phase later than the one declared in `CLAUDE.md`.

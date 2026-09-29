# Zones

How the homelab network is laid out, and why. **The code decides**: the zones,
the VMs, the transit matrix and the node's ports live in
[`environments/prod/terraform.tfvars`](../environments/prod/terraform.tfvars),
and the `zone-firewall` module turns the matrix into rules. This document
explains that data and keeps what cannot be code: the reserved ranges, the
addressing plan for later phases, and the invariants.

## Zones

Each zone is a VNet in one Proxmox SDN Simple zone (`homelab`), with a subnet
whose gateway is the host (`.1`) and SNAT for egress through `eno1`. They are
the `zones` map in `terraform.tfvars`, keyed by VNet ID (at most 8 letters and
digits); `alias` is the name everything else uses.

| Zone | CIDR | VNet |
|---|---|---|
| `mgmt` | 10.10.0.0/24 | `mgmt` |
| `ci` | 10.10.1.0/24 | `ci` |
| `platform` | 10.10.4.0/24 | `platform` |

`mgmt` and `ci` together, `10.10.0.0/22`, are the control zones: the only ones
that reach the node's admin ports. `platform` holds the RKE2 cluster and the
LB pair: the public tunnel, the API, the data services and the web ingress all
live inside it, so it is the only zone with a broad set of internal rules
(below).

## Reserved ranges

No zone, VM or service may use these ranges. **Always** check before proposing
a new IP. The `zones` validation keeps every zone inside `10.10.0.0/16`, which
none of them touches.

| Range | For |
|---|---|
| 10.11.0.0/16 | node 2 (phase 5) |
| 10.20.0.0/16 | Hetzner Cloud and vSwitch (phase 4) |
| 10.42.0.0/16 | RKE2 pods (phase 2) |
| 10.43.0.0/16 | RKE2 services (phase 2) |
| 10.66.66.0/24 | future lab |

## Machines

What exists is the `vms` map in `terraform.tfvars`. This is the plan, later
phases included, so that no address is handed out twice:

| VM | Zone | IP | Phase |
|---|---|---|---|
| `vm-access-01` | mgmt | 10.10.0.10 | 1 |
| `vm-access-02` | mgmt | 10.10.0.20 | 1 |
| `vm-ci` | ci | 10.10.1.10 | 1 |
| `vm-lb-01` | platform | 10.10.4.11 | 2 |
| `vm-lb-02` | platform | 10.10.4.12 | 2 |
| `vm-rke2-01` | platform | 10.10.4.21 | 2 |
| `vm-rke2-02` | platform | 10.10.4.22 | 2 |
| `vm-rke2-03` | platform | 10.10.4.23 | 2 |

The `platform` VIP, `10.10.4.10`, is not a VM: it is the keepalived address the
two `vm-lb` VMs share, in front of HAProxy. `vm-lb-01` and `vm-lb-02` run
HAProxy, keepalived and the public tunnel's cloudflared connectors; the three
`vm-rke2` VMs are identical RKE2 servers — control plane, etcd and workloads
together, no dedicated agent.

Packer builds a template on a throwaway VM, cloned from the previous template
in the chain (`packer/build-order`), which becomes the new template when the
build ends: the old template is deleted by name first, and the new one takes
the same fixed VMID. It lives in `ci` at **10.10.1.250**, where the runner
that drives it can reach it over SSH, and no machine may take that address.
Packer cannot set a VM's firewall options, so the build VM is the one NIC
without zone filtering, for the minutes the build lasts.

## Transit matrix

The `transit` list in `terraform.tfvars`: every flow the firewall allows.
Anything not listed is denied. Every entry has a `proto` — `tcp` by default,
`udp` or `vrrp` otherwise — and `vrrp` entries carry no ports: the protocol has
none. Every rule the module creates is commented `<from> -> <to>: <note>`, so a
rule in Proxmox always traces back to its line of the matrix.

- An entry towards a **zone** becomes an inbound rule in that zone's security
  group (`zone-<vnet>`), sourced from the `from` zone's CIDR. Every VM gets its
  zone's group, input DROP, and its own firewall on.
- An entry towards the **node** becomes a node rule. From a control zone only
  the node's `admin_ports` (`node_firewall`) survive: `mgmt`'s admin entry
  gives it 22 and 8006 on the node, and its Traefik entry 443; `ci` gets 443
  and 8006. From anywhere else, the entry's ports as written: 9100 from
  `platform`, for the node metrics scrape.
- An entry towards the **internet** is egress, allowed by the outbound policy
  of every zone that has one.
- An entry with an empty `to` gives that zone's VMs an outbound DROP policy.
  Nothing uses it today — every zone reaches at least the node or the
  internet — but the mechanism stays for a zone that must initiate nothing, as
  `data` once did.

## Invariants

Checked by the `homelab:network-reviewer` agent before every PR. Those marked
**(code)** are also validations in `environments/prod/variables.tf`: a plan
that breaks them fails.

1. Every IP falls inside its zone and none is the host's `.1` **(code)**, and
   none lands on a reserved range.
2. No duplicate IPs **(code)**.
3. Every firewall rule traces to an entry of the matrix. A rule with no backing
   is a **critical** finding.
4. Every entry is `tcp`, `udp` or `vrrp`; `tcp` and `udp` entries list their
   ports, `vrrp` entries list none **(code)**. No zone initiates towards an
   empty `to` today, but the mechanism — an explicit outbound DROP policy —
   stays available for one that must.
5. Nothing enters `mgmt` from another zone **(code)**. SSH between the two
   `vm-access` connectors, inside `mgmt`, is the only way in.
6. The node stays on DROP, with only 22, 443 and 8006 from `10.10.0.0/22` (22
   never from `ci`), 9100 from `platform`, and from the internet only SSH as
   break-glass, closed by the Hetzner firewall until opened **(code)**. Any
   other ingress to the node is a **critical** finding, and so is implicit
   admin access: `local_network` stays pointed at loopback.
7. No admin interface reaches the internet through the public tunnel: portals
   sit behind Cloudflare Access, Vault and the Kubernetes API are reached only
   over WARP.
8. No VM from a phase later than the one declared in `CLAUDE.md`.

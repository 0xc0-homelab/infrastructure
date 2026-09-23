# infrastructure

Proxmox VE 9 on a Hetzner dedicated server (`pve-1`, `pve.0xc0.cc`), 2× NVMe
in mdadm RAID 0, no ZFS. A single node until phase 5. The host is router and
firewall and holds `.1` in every zone; `eno1` keeps the public IP, each zone
is an SDN VNet with no physical port, and egress is SNAT through `eno1`.

The host also runs Traefik, RustFS and PBS. They are **not managed from this
repo** and must never be touched by it: Traefik is the reverse proxy for the
Proxmox UI, PBS and RustFS; RustFS holds the OpenTofu state; PBS backs up to a
Hetzner Storage Box. Any change here that could cut the host's public access —
firewall rules on `eno1` above all — puts those three at risk.

OpenTofu (templates from official cloud images, VMs, network, firewall) →
Ansible (configuration). Packer arrives in phase 2, for templates that must be
baked (the CI runner, zones with no egress).
Proxmox provider: `bpg/proxmox`. Zones are Proxmox SDN: one Simple zone, a
VNet and a subnet per zone, with the host as gateway and SNAT for egress, all
in OpenTofu. Use the `proxmox_sdn_*` resources — the
`proxmox_virtual_environment_sdn_*` ones are deprecated. Zones spanning nodes
arrive with node 2 in phase 5.

Cloudflare — tunnels, Zero Trust, DNS — lives in the same root,
`environments/prod/`, alongside the node (operator decision, 2026-09-23):
`prod` is the one environment, with everything that makes it up. Split by
service only if the coupling ever gets in the way.

## CURRENT PHASE: 1 (Base)

Scope of phase 1: Proxmox, zones, NAT, the Debian base template, `vm-access`,
`vm-edge`. SOPS
working. Rescue and WARP tested. Everything driven manually from the laptop.

Do not implement VMs or services from later phases even if they fit. The phase
of each VM is in `docs/zones.md`. If something requires a future phase, say so
and stop.

## Architecture

`docs/architecture.md` explains how the node, the zones, the flows, CI and the
secrets fit together, with diagrams. Read it before a change that touches more
than one of them. It explains; `docs/zones.md` and the workspace
`docs/design.md` decide.

## Ansible

`ansible/` configures what runs inside the VMs, after cloud-init. Run it
through `scripts/ansible`, which reads the tunnel token from the OpenTofu state
into the environment, never onto disk:

```
scripts/ansible playbooks/vm-access.yml --check --diff
```

The node itself is touched by Ansible **only** for what the SDN needs:
`playbooks/node.yml` keeps `data` from egressing, in `DOCKER-USER`, and accepts
the other zones' egress and its replies there. Traefik, RustFS, PBS and Docker
itself are never touched from this repo. Docker carries one setting by hand,
`ip-forward-no-drop`, that the zone firewall needs (`docs/architecture.md`,
The node).

Until admin access through WARP is tested (#12), `bootstrap_via_host: true` in
`inventory/group_vars/vms.yml` makes Ansible jump through the node (the
operator's `hetzner` SSH alias). After that it goes through WARP, and the jump
is switched off.

Every role follows the `ansible-role` skill and passes `ansible-lint` on the
`production` profile.

## Network source of truth

`docs/zones.md`. It holds the zones, the reserved ranges, the IP of each VM and
the transit matrix.

**Before proposing any IP or subnet, check it against that file.** There are
five reserved ranges that can never be used (node 2, Hetzner Cloud, RKE2 pods
and services, lab).

## Hard rules

- Everything written is in English: files, file names, comments, commits,
  branches and PRs.
- No work without an issue on the org project board. The PR links it
  (`Closes #N` / `Refs owner/repo#N`) or the `issue` check fails. See the
  workspace `CLAUDE.md`, section Tracking.
- `environments/prod/firewall.tf` is **generated** from the matrix in
  `docs/zones.md` by `scripts/generate-firewall`. Do not hand-edit it: change
  the matrix and regenerate (skill `firewall-matrix`). Every generated rule
  carries the `id` of its matrix line, and the `firewall-matrix` check fails a
  PR whose `firewall.tf` does not match.
- Zone filtering happens on each guest's NIC (`modules/zone-firewall`). Every
  VM has its own firewall on: the node's `FORWARD` policy is ACCEPT, so a VM
  without one is not filtered at all.
- `data` does not initiate connections anywhere. Never add an egress rule from
  `data`.
- Nobody initiates towards `mgmt`.
- The node has a DROP policy: 22 and 8006 from `10.10.0.0/22`, plus 443 from
  the internet for Traefik (`t11`) until the CI runner exists.
- The node DROP is applied **last** in phase 1, only once admin access through
  `vm-access` and WARP has been tested. Applied earlier, it locks the operator
  out: `10.10.0.0/22` has no hosts yet.
- `ci` reaches the node over 8006 (API), never over 22.
- Private dashboards go through the `vm-access` tunnel, never through
  `vm-edge`.
- Secrets with SOPS+age. An unencrypted file holding sensitive material is a
  bug, not a TODO. From phase 3 onwards, progressive migration to Vault over
  OIDC.
- Do not run `tofu apply`, `tofu destroy` or `ansible-playbook` without
  `--check`. The human runs the apply after manual approval of the PR.
- Idempotent playbooks: no `shell`/`command` without `creates:` or
  `changed_when:`.
- Disks and volumes holding data carry `lifecycle { prevent_destroy = true }`.
- The provider **never** gets SSH to the node. Everything goes through the API:
  import disks with `import_from`, never `file_id`; no cloud-init snippets.
  Both would make the provider SSH into the host. What a VM needs beyond its
  image is Ansible's job.
- VMs use VMIDs 100-8999. Every NIC has the Proxmox firewall on, or zone rules
  do not apply to it.
- Templates use VMIDs 9000-9099, and their image is a pinned, dated build with
  its published SHA-512 — never a `latest` link.
- OpenTofu is **always** written as modules, with Google's layout:
  `modules/<name>/` holds the resources, `environments/<env>/` holds the roots,
  which only call modules. A VM, a firewall and a network are modules; the
  root wires them together.
- Each root has its own state key, `homelab/infrastructure/<env>.tfstate`, in
  RustFS (`https://s3.0xc0.cc`, bucket `tfstate`). Never share a key. Keep a
  root under a few dozen resources: every run refreshes all of it.
- A resource that is the only one of its type is named `main`. Root values go
  in `terraform.tfvars`; secrets come from the environment. Module READMEs
  carry a generated inputs/outputs section (`terraform-docs`).
- Plans and applies in CI use the reusable `tofu-plan` and `tofu-apply`
  workflows from `0xc0-homelab/.github`. Do not write local copies of them.

## Before opening a PR

Run the `homelab:network-reviewer` agent if the change touches network,
firewall, addressing or inventory. Check the eight invariants in
`docs/zones.md`.

## Repo policy

`main` only. PR required. The apply needs manual approval.

## open-appsec

It is the least battle-tested piece of the stack and there is little reliable
documentation in model training data. **Do not invent directives or policy
names.** If you are unsure about the syntax, say so and check the official
documentation.

## Skills in this repo

Under `.claude/skills/`, for the operations that repeat here:

| Skill             | Use it when                                          |
|-------------------|------------------------------------------------------|
| `new-vm`          | adding, moving or re-addressing a VM                 |
| `firewall-matrix` | opening, closing or reviewing a port between zones   |
| `packer-template` | a baked template — from phase 2 only                 |
| `ansible-role`    | creating, restructuring or reviewing a role          |

`new-vm` and `firewall-matrix` both write to `docs/zones.md`. That file is
normative: it is edited first, and everything else is derived from it.

## Claude Code plugins enabled here

`homelab@0xc0-homelab` (agents and hooks) and `terraform@hashicorp` (official
HashiCorp skills), both declared in `.claude/settings.json`.

Caveats:

- They are written for Terraform; this repo runs **OpenTofu**. Treat their
  output as a starting point and check the command names and any
  Terraform-Cloud-only feature.
- The `terraform-stacks` skill may trigger on its own. Stacks is **discarded**
  here (paid). Ignore it if it fires.
- The `packer@hashicorp` plugin is deliberately **not** enabled: its four
  skills are AWS, Azure, Windows and HCP registry. None applies to Proxmox.

## Discarded — do not propose it

WireGuard (Access+WARP covers it) · Traefik as ingress (with no containers
alongside it adds nothing over NGINX; it only runs on the host as its reverse
proxy, outside IaC) · Coraza (open-appsec avoids tuning the CRS) ·
BunkerWeb (config in SQLite) · OPNsense and VyOS (fragile hop, immature
providers) · VLAN zones now (an SDN Simple zone covers one node) · Terraform Stacks
(paid) · OpenBao (Vault's BSL does not affect this case) · Loki and Tempo now.

Full reasoning in `../docs/design.md`.

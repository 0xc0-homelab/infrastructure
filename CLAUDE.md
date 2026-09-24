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

OpenTofu (the official cloud image as a raw template, VMs, network, firewall)
→ Packer (the templates VMs clone: `debian-13-base`, and the ones built on it)
→ Ansible (configuration). No VM clones the raw image.
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

Phase 1 is complete: Proxmox, zones, NAT, the Packer templates, `vm-access-01`,
`vm-access-02` and `vm-ci` with the self-hosted runners. SOPS works, Rescue
and WARP are tested. `vm-edge` and `vm-apps` are phase 2: there is nothing to
publish yet (operator decision, 2026-09-23).

Do not implement VMs or services from later phases even if they fit. The phase
of each VM is in `docs/zones.md`, Machines. If something requires a future phase, say so
and stop.

## Architecture

`docs/architecture.md` explains how the node, the zones, the flows, CI and the
secrets fit together, with diagrams. Read it before a change that touches more
than one of them. It explains; the code and the workspace `docs/design.md`
decide.

## Ansible

`ansible/` configures what runs inside the VMs, after cloud-init. Run it
through `scripts/ansible`, which reads the tunnel token from the OpenTofu state
into the environment, never onto disk:

```
scripts/ansible playbooks/vm-access.yml --check --diff
```

The node itself is touched by Ansible **only** for what the SDN needs:
`playbooks/node.yml` keeps `data` from egressing, with a DROP rule in
`DOCKER-USER`. The other zones need no rule of their own: Docker carries one
setting by hand, `ip-forward-no-drop`, that keeps the `FORWARD` policy ACCEPT
(`docs/architecture.md`, The node). Traefik, RustFS, PBS and Docker itself are
never touched from this repo.

Ansible reaches every VM directly over WARP.

`playbooks/vm-ci.yml` runs the `github_runner` role: ephemeral runners, each
fetching a just-in-time config from a GitHub App of their own before every
job. The App key comes from `secrets/ansible.sops.yaml` and is readable only
by root on `vm-ci`; jobs run as the unprivileged `runner` user.

Every role follows the `ansible-role` skill and passes `ansible-lint` on the
`production` profile.

## Packer

`packer/<template>/` bakes the templates every VM clones, in
`packer/build-order`: `debian-13-base` from the raw `debian-13-cloud`, with the
`base` role, and `debian-13-runner` from `debian-13-base`, with the runner.
Secrets and per-VM settings stay in Ansible. `scripts/packer <template>
validate` locally. Every merge to `main` that touches `packer/` or the roles
rebuilds them all in CI, after approval: each one deleted by name and built
again. Skill `packer-template`.

## Network source of truth

The code: `environments/prod/terraform.tfvars` holds the zones, the VMs, the
transit matrix (`transit`) and the node's admin ports (`node_firewall`). The
`zone-firewall` module turns the matrix into every zone's and the node's rules;
nothing is generated into a file. Validations in `variables.tf` enforce the
invariants they can.

`docs/zones.md` explains that data and keeps what cannot be code: the reserved
ranges, the addressing plan for later phases, the Packer build address and the
invariants. **Before proposing any IP or subnet, check it against that file.**
There are five reserved ranges that can never be used (node 2, Hetzner Cloud,
RKE2 pods and services, lab).

## Hard rules

- Everything written is in English: files, file names, comments, commits,
  branches and PRs.
- No work without an issue on the org project board. The PR links it
  (`Closes #N` / `Refs owner/repo#N`) or the `issue` check fails. See the
  workspace `CLAUDE.md`, section Tracking.
- Every firewall rule comes from the `transit` matrix in `terraform.tfvars`
  (skill `firewall-matrix`), never written as a resource by hand. Its comment
  is `<from> -> <to>: <note>`, so any rule in Proxmox traces back to its line.
- Zone filtering happens on each guest's NIC (`modules/zone-firewall`). Every
  VM has its own firewall on: the node's `FORWARD` policy is ACCEPT, so a VM
  without one is not filtered at all.
- `data` does not initiate connections anywhere. Never add an egress rule from
  `data`.
- No other zone initiates towards `mgmt`. SSH between the `vm-access`
  connectors, inside `mgmt`, is the only way in.
- The node has a DROP policy (`node_firewall_enabled`): 22, 443 and 8006
  from `mgmt`, 443 and 8006 from `ci`, 9100 and 10250 from `platform`,
  and nothing from the internet. All of it from the matrix. Admin access to
  the node, Traefik included, is over WARP only, to `10.10.0.1`: Gateway
  resolves `node_web_hostnames` there. The Hetzner Rescue system is the way
  back in.
- `local_network` is overridden to loopback, so Proxmox grants no implicit
  admin access to the network it detects. Never remove that alias.
- A change to the node firewall is tested first by hand, with a rollback
  scheduled on the node itself (systemd timer), before it goes into code.
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
  Both would make the provider SSH into the host. Packer bakes the shared
  baseline into the template; Ansible configures each VM from there.
- Nobody picks a VM's VMID: Proxmox assigns the next free one, from 100, and
  the state keeps it. Every NIC has the Proxmox firewall on, or zone rules do
  not apply to it.
- **No VM is destroyed** as a matter of course: the `vm` module sets
  `prevent_destroy`, so a plan that deletes or replaces one fails. A deliberate
  rebuild bumps the VM's `rebuild` in `terraform.tfvars` **and** lifts
  `prevent_destroy` in the same PR; the next PR sets it back. Rebuilding
  `vm-ci` runs from the laptop: in CI it would destroy its own runner.
- Templates are found by **name**, never by VMID: Proxmox assigns their VMIDs
  too, and a rebuild gives a new one. The raw cloud image is a pinned, dated
  build with its published SHA-512, never a `latest` link. A VM ignores later
  changes to its template; moving it onto a new one is bumping its `rebuild`.
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
| `packer-template` | a baked template                                     |
| `ansible-role`    | creating, restructuring or reviewing a role          |

`new-vm` and `firewall-matrix` both edit `environments/prod/terraform.tfvars`,
which decides, and keep `docs/zones.md`, which explains, in step.

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

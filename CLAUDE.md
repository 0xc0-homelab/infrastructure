# infrastructure

Proxmox VE 9 on a Hetzner dedicated server (`pve-1`, `pve.0xc0.cc`), 2× NVMe
in mdadm RAID 0, no ZFS. A single node. The host is router and
firewall and holds `.1` in every zone; `eno1` keeps the public IP, each zone
is an SDN VNet with no physical port, and egress is SNAT through `eno1`.

The host also runs Traefik, RustFS and PBS. They are **not managed from this
repo** and must never be touched by it: Traefik is the reverse proxy for the
Proxmox UI, PBS and RustFS; RustFS holds the OpenTofu state; PBS backs up to a
Hetzner Storage Box. Any change here that could cut the host's public access —
firewall rules on `eno1` above all — puts those three at risk.

OpenTofu (the official cloud image as a raw template, VMs, network, firewall)
→ Packer (the templates VMs clone: `debian-13-base`, `rocky-10-base`, and the
ones built on them)
→ Ansible (configuration). No VM clones the raw image.
Proxmox provider: `bpg/proxmox`. Zones are Proxmox SDN: one Simple zone, a
VNet and a subnet per zone, with the host as gateway and SNAT for egress, all
in OpenTofu. Use the `proxmox_sdn_*` resources — the
`proxmox_virtual_environment_sdn_*` ones are deprecated. There is no second
node, so no zone spans nodes.

Cloudflare — tunnels, Zero Trust, DNS — lives in the same root,
`environments/prod/`, alongside the node (operator decision, 2026-09-23):
`prod` is the one environment, with everything that makes it up. Split by
service only if the coupling ever gets in the way.

## What runs

On the node: the zones, NAT, the zone and node firewalls, the Packer
templates, `vm-access-01` and `vm-access-02` (the admin connectors),
`vm-ci-01` and `vm-ci-02` with the self-hosted runners, and one RKE2 cluster
in `platform` behind the HAProxy load balancer pair that carries the public
tunnel. In the cluster: ArgoCD, Longhorn, the ingress (Traefik) with its WAF
(CrowdSec), and Vault, which holds every secret this repo uses
(`ci/infrastructure/*`, `ci/shared/*`). PBS backs every VM up daily. The
addressing plan of every VM is in `docs/zones.md`, Machines.

## Architecture

`docs/architecture.md` explains how the node, the zones, the flows, CI and the
secrets fit together, with diagrams. Read it before a change that touches more
than one of them. It explains; the code and the workspace `docs/design.md`
decide.

## Ansible

`ansible/` configures what runs inside the VMs, after cloud-init. **Every
playbook runs from the pipeline** (operator decision, 2026-09-29):
`.github/workflows/ansible.yml` calls the reusable workflow in
`0xc0-labs/.github`, which runs them in order with `--check --diff` on a
PR, and for real on a merge to `main` once the operator approves. Nothing is
applied from the laptop.

Locally, only the dry run, through `scripts/ansible`, which reads the tunnel
token and the admin keys from the OpenTofu state into the environment, never
onto disk:

```
scripts/ansible playbooks/vm-access.yml --check --diff
```

Every play goes one host at a time (`serial`), so a bad change stops at the
first and the other keeps the service. A dry run changes nothing:
`scripts/ansible` runs it on every host at once (`play_serial`).

Ansible never touches the node. Every zone reaches the internet, so the node
needs no forwarding rule of its own: Docker carries one setting by hand,
`ip-forward-no-drop`, that keeps the `FORWARD` policy ACCEPT
(`docs/architecture.md`, The node). A zone that must never egress would need a
DROP rule in `DOCKER-USER`; the `node_forwarding` role that wrote it is in
git history (#101). Traefik, RustFS, PBS and
Docker itself are never touched from this repo.

Ansible reaches every VM directly over WARP.

`playbooks/vm-ci.yml` runs the `github_runner` role: ephemeral runners, each
fetching a just-in-time config from a GitHub App of their own before every
job. The App key comes from Vault (`ci/infrastructure/runner-app`) and is
readable only by root on the CI VMs, `vm-ci-01` and `vm-ci-02`; jobs run as the
unprivileged `runner` user. Each runner carries the `0xc0` label and its
VM's name, so a job can pin itself to one VM.

`playbooks/cluster.yml` builds the cluster: `haproxy`, `keepalived` and the
public tunnel's `cloudflared` on the `lb` pair, holding the VIPs, then
`longhorn_node`, `rke2_server` and `argocd` on each server, one at a time, and
last `longhorn_node` and `rke2_agent` on each agent. The first server
initialises the cluster; the others join through the VIP, with the token from
Vault (`ci/infrastructure/rke2`). The `argocd` role writes ArgoCD's
`HelmChart` and the root `Application` into RKE2's manifests directory: RKE2's helm-controller
installs ArgoCD, and ArgoCD syncs `bootstrap/prod/` from `gitops` (operator
decision, 2026-09-29). There is no OpenTofu root for the cluster. The admin kubeconfig is
stored nowhere but on the servers (operator decision, 2026-09-29): whatever
needs it, the pipeline or the laptop, reads it over SSH from a server, into
memory.

Every role follows the `ansible-role` skill and passes `ansible-lint` on the
`production` profile.

## Packer

`packer/<template>/` bakes the templates every VM clones, in
`packer/build-order`: `debian-13-base` from the raw `debian-13-cloud`, with the
`base` role, `debian-13-runner` from `debian-13-base`, with the runner, and
`rocky-10-base` from the raw `rocky-10-cloud`, with the `base` role, for the
RKE2 nodes.
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
ranges, the addressing plan, the Packer build addresses and the
invariants. **Before proposing any IP or subnet, check it against that file.**
There are five reserved ranges that can never be used (a second node, Hetzner
Cloud, RKE2 pods and services, lab).

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
- No zone must initiate towards a destination that isn't in `transit`: an
  entry with an empty `to` gives that zone's VMs an outbound DROP policy. None
  today, but the mechanism stays for a zone that must never egress.
- No other zone initiates towards `mgmt`, with one exception: SSH from the
  CI VMs named in its `transit` entry (`sources`), never the whole `ci` zone,
  so the pipeline can run the vm-access playbook (operator decision,
  2026-09-29). Besides that, SSH between the `vm-access` connectors, inside
  `mgmt`, is the only way in.
- The node has a DROP policy (`node_firewall_enabled`): 22, 443 and 8006
  from `mgmt`, 443 and 8006 from `ci`, 9100 from `platform`, and
  only SSH (22) from the internet, as break-glass: the Hetzner firewall keeps
  it closed until the operator opens it, and sshd is key-only. All of it from
  the matrix. Day-to-day admin access to the node, Traefik included, is over
  WARP, to `10.10.0.1`: Gateway resolves `node_web_hostnames` there. The
  Hetzner Rescue system is the last way back in.
- `local_network` is overridden to loopback, so Proxmox grants no implicit
  admin access to the network it detects. Never remove that alias.
- A change to the node firewall is tested first by hand, with a rollback
  scheduled on the node itself (systemd timer), before it goes into code.
- `ci` reaches the node over 8006 (API), never over 22.
- No admin interface reaches the internet through the public tunnel: the
  portals, Vault and the Kubernetes API are reached only over WARP, through
  the admin tunnel. No portal is published behind Cloudflare Access either.
- Secrets live in Vault, never in this repo (.github#6): CI reads them over
  JWT with GitHub's OIDC token (role `infrastructure`), the scripts locally
  with the operator's token (`scripts/vault-env`). A file holding sensitive
  material is a bug, not a TODO.
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
  `prevent_destroy` in the same PR; the next PR sets it back. No run ever
  restarts a VM on its own either (`reboot_after_update = false`): a change
  that needs one stays pending in Proxmox, and `scripts/rolling-reboot
  <vm>...` restarts them one at a time, waiting for each (and, for an RKE2
  node, its node Ready and Longhorn healthy) before the next. A CI VM is
  rebuilt from the pipeline too, one at a time: the same PR points
  `.github/workflows/apply.yml`'s `runs-on` at the **other** VM's label, so
  the apply never runs on the VM it destroys; the next PR points it back at
  `0xc0`.
- Templates are found by **name**, never by VMID. Each still takes a fixed
  VMID, so the ID says what it is: 9000-9099 for the raw images (`vm_id` in
  `templates`), 9100-9199 for Packer's (`vm_id` in the template), kept across
  rebuilds. The raw cloud image is a pinned, dated
  build with its published checksum, never a `latest` link. A VM ignores later
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
  workflows from `0xc0-labs/.github`. Do not write local copies of them.

## Before opening a PR

Run the `0xc0:network-reviewer` agent if the change touches network,
firewall, addressing or inventory. Check the invariants in
`docs/zones.md`.

## Repo policy

`main` only. PR required. The apply needs manual approval.

## The cluster's ingress and WAF

Traefik with the Gateway API, and CrowdSec in front of it, both deployed by
ArgoCD from `gitops` (operator decision, 2026-09-29). Their secrets come from
Vault through Vault Secrets Operator, not from this repo. There is no
open-appsec, and the load balancers stay layer 4.

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

`0xc0@0xc0-labs` (agents and hooks) and `terraform@hashicorp` (official
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

WireGuard (Access+WARP covers it) · Coraza (the CRS needs hand-tuning;
CrowdSec's virtual patching does not) · open-appsec (its Kubernetes
integrations run on retired or unmaintained pieces) · kube-vip and MetalLB
(the load balancer VMs keep the VIP) · BunkerWeb (config in SQLite) ·
OPNsense and VyOS (fragile hop, immature providers) · VLAN zones (an SDN
Simple zone covers one node) · Terraform Stacks (paid) · OpenBao (Vault's BSL
does not affect this case) · Prometheus, Grafana, Loki and Tempo (OpenObserve
covers the three signals).

Full reasoning in `../docs/design.md`.

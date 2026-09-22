# Architecture

How the pieces of the homelab fit together. The **decisions** behind them —
and what was discarded, and why — live in
[`workspace/docs/design.md`](https://github.com/0xc0-homelab/workspace/blob/main/docs/design.md).
The **network** is normative in [`zones.md`](zones.md). This document explains;
those two decide. If they disagree with this one, they win.

Most of what follows is the target of phase 1 and later. Each section says
what exists **today** and what is **target**.

## The node

One Hetzner dedicated server, `pve-1` (`pve.0xc0.cc`): Proxmox VE 9, 12 CPU,
62 GB RAM, two NVMe disks in mdadm RAID 0.

```mermaid
flowchart TB
  internet(("Internet"))

  subgraph host["pve-1 — Hetzner dedicated"]
    eno1["eno1<br/>public IP"]

    subgraph base["Base services — outside IaC"]
      traefik["Traefik<br/>reverse proxy, 443"]
      pveui["Proxmox UI / API"]
      pbs["PBS"]
      rustfs["RustFS<br/>OpenTofu state"]
    end

    subgraph sdn["SDN Simple zone — managed by OpenTofu"]
      zones["six VNets, one per zone<br/>host is .1 in each"]
    end
  end

  sbox[("Hetzner Storage Box<br/>PBS datastore")]

  internet -- "443 (t11)" --> eno1 --> traefik
  traefik --> pveui
  traefik --> pbs
  traefik --> rustfs
  pbs --> sbox
  zones -- "SNAT" --> eno1
```

- **Base services** — Traefik, RustFS and PBS run on the host itself. They are
  not managed by any repo in this org and nothing here may touch them. Traefik
  is only the host's reverse proxy; it is not the application ingress.
- **Disks** — RAID 0, by decision: there is no redundancy on the node. One
  NVMe failure loses it, and recovery is a reinstall plus a restore from PBS
  on the Storage Box.
- **`eno1`** keeps the public IP. Guests never attach to it: Hetzner drops
  unknown MACs on the public interface. They live on internal VNets, and reach
  the internet through SNAT on the host.

**Today:** Proxmox, Traefik, RustFS and PBS run. There are no VNets, no
guests, and the Proxmox firewall is off. **Target:** everything below.

## Zones

Each zone is a VNet in one SDN Simple zone, with a subnet whose gateway `.1` is
the host. The host routes between zones and applies the firewall; everything
not listed in the transit matrix is denied.

```mermaid
flowchart LR
  subgraph control["control — 10.10.0.0/22"]
    mgmt["mgmt<br/>10.10.0.0/24<br/>vm-access .10"]
    ci["ci<br/>10.10.1.0/24<br/>vm-ci .10 · phase 2"]
  end
  platform["platform<br/>10.10.4.0/24<br/>vm-vault .10 · phase 3<br/>vm-platform .20 · phase 3"]
  edge["edge<br/>10.10.8.0/24<br/>vm-edge .10"]
  workloads["workloads<br/>10.10.16.0/20<br/>vm-apps .10 · phase 2<br/>vm-rke2 .20 · phase 6"]
  data["data<br/>10.10.32.0/24<br/>vm-data .10 · phase 2"]
  node["node<br/>pve-1"]
  internet(("internet"))

  mgmt -- "t01 · admin" --> ci & platform & edge & workloads & data & node
  ci -- "t02 · 22" --> edge & platform & workloads & data
  ci -- "t03 · 8006" --> node
  ci -- "t04 · 8200" --> platform
  edge -- "t05 · 8080, 30000-32767" --> workloads
  workloads -- "t06 · 5432, 6379" --> data
  workloads -- "t07 · 8200" --> platform
  platform -- "t08 · 9100, 10250" --> workloads & data & node
  platform -- "t09 · 443" --> internet
  internet -- "t11 · 443" --> node
```

The arrows are the `id`s of the transit matrix in [`zones.md`](zones.md). Two
things the diagram shows by what is missing:

- **Nothing points at `mgmt`.** Nobody initiates towards the management zone.
- **Nothing leaves `data`** (`t10`). It initiates no connection, and its
  subnet has no SNAT either.

The node accepts only 22 and 8006 from `control`, plus 443 from the internet
for Traefik (`t11`) until the CI runner exists.

## Web traffic

```mermaid
sequenceDiagram
  participant U as Visitor
  participant CF as Cloudflare
  participant E as vm-edge
  participant A as vm-apps / cluster ingress

  U->>CF: HTTPS
  CF->>E: Cloudflare Tunnel (outbound from vm-edge)
  Note over E: cloudflared → open-appsec → NGINX, routed by server_name
  E->>A: t05 — 8080 or a NodePort
  A-->>U: response, back through the tunnel
```

No inbound port is opened for web traffic: `cloudflared` on `vm-edge` dials out
to Cloudflare. **No admin panel is ever published this way.** From phase 6 the
WAF moves to the cluster ingress, and is never duplicated.

**Today:** not built. **Target:** phase 1 for `vm-edge`, phase 2 for `vm-apps`.

## Admin access

```mermaid
sequenceDiagram
  participant O as Operator (WARP client)
  participant CF as Cloudflare Access
  participant V as vm-access
  participant Z as any zone, or the node

  O->>CF: WARP, authenticated by Access
  CF->>V: tunnel with WARP routing to 10.10.0.0/16
  V->>Z: t01 — 22, 3389, 6443, 8006, 8200
```

The operator reaches every zone and the node's internal address directly,
without a jump host, as if on the network. Private dashboards — Grafana, Vault
UI, Proxmox — are reached this way, never through the edge.

The **way back in** if this breaks is the Hetzner Rescue system. Phase 1 is not
done until both paths have been tested, and the node's firewall goes to DROP
only after that — before, `10.10.0.0/22` is empty and the DROP would lock the
operator out.

**Today:** the operator reaches the node over its public IP, and the Proxmox
UI through Traefik. **Target:** WARP through `vm-access`, phase 1.

## Changes, CI and state

```mermaid
flowchart LR
  pr["Pull request"] --> plan["tofu-plan<br/>fmt · validate · plan"]
  pr --> issue["issue check<br/>linked issue required"]
  plan -- "plan as a PR comment" --> review["Operator reviews"]
  review --> merge["Squash merge to main"]
  merge --> apply["tofu-apply<br/>waits for approval"]
  apply --> approve{"Operator approves<br/>production"}
  approve --> state[("RustFS<br/>homelab/&lt;repo&gt;/&lt;env&gt;.tfstate")]
  plan -. "reads" .-> state
```

- Every change is a PR linked to an issue on the
  [project board](https://github.com/orgs/0xc0-homelab/projects/1); the
  `issue` check fails without one.
- Plans and applies use the reusable workflows in
  [`0xc0-homelab/.github`](https://github.com/0xc0-homelab/.github). Applies
  wait for the operator's approval in the `production` environment: automation
  plans, a human applies.
- Every OpenTofu root has its own state key in RustFS, locked with a lockfile.
  Plans and applies wait for the lock instead of failing.

**Today:** CI runs on GitHub-hosted runners, so RustFS is reachable from the
internet — temporarily. **Target:** from phase 2, a self-hosted runner on
`vm-ci` inside the network, and RustFS closed again
([`.github#13`](https://github.com/0xc0-homelab/.github/issues/13)).

## Secrets

```mermaid
flowchart LR
  key["age key<br/>operator laptop"] --> sops["SOPS"]
  cikey["CI age key, one per repo<br/>SOPS_AGE_KEY Actions secret"] --> sops
  sops -- "encrypts to both" --> file["secrets/*.sops.yaml<br/>committed, ciphertext only"]
  file -- "scripts/tofu decrypts into env" --> tofu["tofu, locally"]
  file -- "tofu workflows decrypt into env, masked" --> ci["tofu in CI"]
```

- Secrets are committed **encrypted**, to the operator's key and to the repo's
  own CI key. The repos are public, so the ciphertext is too — standard SOPS
  practice; a leaked key means rotating the secrets it protects. Each repo's CI
  key decrypts only that repo's files, and is the only Actions secret there.
- CI masks every decrypted value before using it.
- `scripts/tofu` decrypts into the environment for one command; plaintext
  never reaches disk. Saved plan files are never kept, because they contain
  the variables.
- From phase 2, the CI keys live on `vm-ci` and the Actions secrets go away. From phase 3, secrets move
  progressively to Vault over OIDC.

## Backups

PBS on the host backs up to a datastore on the Hetzner Storage Box. Phase 2
adds an off-site copy to B2 and a restore that is **timed and written down** —
until that restore has been done, the backups are not considered tested. With
RAID 0 on the node, that restore is the recovery plan.

## Where each thing lives

| Concern | Source of truth |
|---|---|
| Decisions, phases, discarded options | [`workspace/docs/design.md`](https://github.com/0xc0-homelab/workspace/blob/main/docs/design.md) |
| Zones, addresses, transit, invariants | [`docs/zones.md`](zones.md) |
| How it fits together | this document |
| State of the work | [project board](https://github.com/orgs/0xc0-homelab/projects/1) |
| Current phase | `CLAUDE.md` of each repo; `/phase` keeps them in sync |
| The org and its repos | [`0xc0-homelab/.github`](https://github.com/0xc0-homelab/.github) |

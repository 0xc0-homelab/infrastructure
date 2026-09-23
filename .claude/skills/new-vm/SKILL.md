---
name: new-vm
description: Adds a new VM to the homelab end to end — picks a free IP in its zone, updates the zones matrix, writes the OpenTofu resource and the Ansible inventory entry. Use whenever a machine is added, moved between zones or re-addressed.
---

# Adding a VM

Four artifacts have to end up consistent: the `vms:` block in `docs/zones.md`,
the OpenTofu resource, the Ansible inventory, and — only if the VM needs new
traffic — the transit matrix. Doing three of the four is the failure mode this
skill exists to prevent.

`docs/zones.md` is normative. It is the first thing edited and the source every
other artifact is derived from.

## Before anything else: the phase gate

Read the `CURRENT PHASE` heading in `CLAUDE.md`. Every VM in `docs/zones.md`
carries a `phase:`. If the requested VM belongs to a later phase, **say so and
stop**. Do not create it because it would fit technically.

## Step 1 — pick the address

| Zone      | Supernet      | Gateway     |
|-----------|---------------|-------------|
| mgmt      | 10.10.0.0/24  | 10.10.0.1   |
| ci        | 10.10.1.0/24  | 10.10.1.1   |
| platform  | 10.10.4.0/24  | 10.10.4.1   |
| edge      | 10.10.8.0/24  | 10.10.8.1   |
| workloads | 10.10.16.0/20 | 10.10.16.1  |
| data      | 10.10.32.0/24 | 10.10.32.1  |

Rules, in order:

1. `.1` is the Proxmox host in every zone. Never allocate it.
2. Hosts are numbered from `.10` upwards in steps of ten: `.10`, `.20`, `.30`.
   Take the lowest free one in that sequence.
3. The address must fall inside its zone's supernet. Check it, do not assume.
4. It must not land on a reserved range — `10.11.0.0/16`, `10.20.0.0/16`,
   `10.42.0.0/16`, `10.43.0.0/16`, `10.66.66.0/24`. These are never used, not
   even temporarily.
5. It must not already appear anywhere in `docs/zones.md` or the inventory.

Read the whole `vms:` block before choosing. Do not infer the next free address
from the last line of the file.

## Step 2 — declare it in the matrix

Add one line to the `vms:` block of `docs/zones.md`, keeping the column
alignment of the existing entries:

```yaml
  vm-example:  { zone: workloads, ip: 10.10.16.30, vcpu: 2, ram_gb: 4,  phase: 2 }
```

## Step 3 — write the OpenTofu resource

Provider is `bpg/proxmox`. The resource takes its zone VNet, its IP and its
gateway from the matrix — never hardcode a literal that already exists as a
variable or a value in `zones.md`.

- Cloud-init for the user, SSH key and network configuration.
- `qemu_agent` enabled: OpenTofu needs it to read the VM's address back.
- Any disk holding data carries `lifecycle { prevent_destroy = true }`.
- The VM clones a template from `modules/cloud-image-template` (VMIDs
  9000-9099), not an ISO. Anything beyond the image is Ansible's job, after
  first boot.

Check the exact field names against the `bpg/proxmox` provider documentation.
Do not invent attribute names from memory.

## Step 4 — add it to the Ansible inventory

One entry, in the group matching its zone, with the same IP. A duplicate IP in
the inventory is a critical finding for `network-reviewer`.

## Step 5 — traffic, only if it needs it

A new VM does **not** get firewall rules by default. Everything not in the
transit matrix is denied, and that is the intended state.

If it genuinely needs to reach something new, that is a separate change: edit
the `transit` block and regenerate with the `firewall-matrix` skill. Never
hand-write a rule in `firewall.tf`.

Two invariants no new VM may break: nothing initiates towards `mgmt`, and
`data` initiates nothing outbound.

## Step 6 — verify and stop

```
tofu fmt && tofu validate && tofu plan
ansible-inventory --list
```

Run `network-reviewer` before opening the PR. Show the plan and stop — the
apply is launched by the human.

## Check before calling it done

- The IP is inside its zone supernet, off every reserved range, and unique.
- `docs/zones.md`, the OpenTofu resource and the inventory all agree.
- The VM's `phase:` is not later than the current phase.
- Data disks carry `prevent_destroy`.
- `firewall.tf` untouched unless the matrix changed too.

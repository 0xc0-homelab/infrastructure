---
name: new-vm
description: Adds a new VM to the homelab end to end — picks a free IP in its zone, adds it to the vms map, the addressing plan and the Ansible inventory. Use whenever a machine is added, moved between zones or re-addressed.
---

# Adding a VM

Four things have to end up consistent: the `vms` map in
`environments/prod/terraform.tfvars`, which decides, the addressing plan in
`docs/zones.md`, the Ansible inventory, and — only if the VM needs new traffic
— the transit matrix. Doing three of the four is the failure mode this skill
exists to prevent.

## Before anything else: the phase gate

Read the `CURRENT PHASE` heading in `CLAUDE.md`. Every VM in the addressing plan
of `docs/zones.md` carries a phase. If the requested VM belongs to a later phase, **say so and
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
5. It must not already appear in the `vms` map, the addressing plan of
   `docs/zones.md` or the inventory.

Read the whole plan before choosing. Do not infer the next free address from
the last line.

## Step 2 — add it to the vms map

One entry in `vms`, in `environments/prod/terraform.tfvars`: its template, VNet,
IP and size. No VMID: Proxmox assigns one. The `vm` module does the rest, and
its firewall comes with it. Add the same VM to the addressing plan in
`docs/zones.md`, with its phase.

- Any disk holding data carries `lifecycle { prevent_destroy = true }`.
- The VM clones a template (the imported base or one Packer baked), not an ISO.
  Anything beyond the image is Ansible's job, after first boot.

## Step 4 — add it to the Ansible inventory

One entry, in the group matching its zone, with the same IP. A duplicate IP in
the inventory is a critical finding for `network-reviewer`.

## Step 5 — traffic, only if it needs it

A new VM does **not** get firewall rules by default. Everything not in the
transit matrix is denied, and that is the intended state.

If it genuinely needs to reach something new, that is a separate change: an
entry in the `transit` matrix, with the `firewall-matrix` skill.

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
- The `vms` map, the plan in `docs/zones.md` and the inventory all agree.
- The VM's `phase:` is not later than the current phase.
- Data disks carry `prevent_destroy`.
- The transit matrix untouched unless the VM needs new traffic.

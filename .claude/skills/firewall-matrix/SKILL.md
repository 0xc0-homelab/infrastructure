---
name: firewall-matrix
description: Opens, closes or reviews a port between zones by editing the transit matrix in docs/zones.md and regenerating firewall.tf. Use whenever traffic between zones changes, or firewall.tf and the matrix may have diverged.
---

# Changing the zone firewall

`docs/zones.md` is normative. `environments/prod/firewall.tf` is generated from
it and **never edited by hand** — a hook blocks it, and the `firewall-matrix`
check fails any PR whose `firewall.tf` does not match the matrix.

The flow is always: edit the matrix → regenerate → read the plan.

## Procedure

1. Edit the `transit` block of `docs/zones.md`: change an entry, or add one
   with the next free `id` and a `note` saying why. Ports are TCP.
2. Run `scripts/generate-firewall`. It rewrites `firewall.tf` whole — no partial
   patching.
3. `scripts/tofu prod plan` and read every changed rule.
4. Open the PR. `network-reviewer` checks the invariants; the `firewall-matrix`
   check proves the generated file matches the matrix.

## What the generator does

- Every entry whose `to` is a zone becomes an inbound rule in that zone's
  security group (`zone-<vnet>`), sourced from the `from` zone's CIDR, with the
  entry's `id` and note in the comment.
- Every `to: [node]` entry becomes a rule of the node firewall
  (`node_firewall_rules`). From a control zone (`mgmt`, `ci`) only its ports
  among the node's `ingress_ports` survive: `t01` gives `mgmt` 22 and 8006,
  `t03` gives `ci` 8006. Any other source keeps the entry's ports.
- `to: [internet]` entries are egress, allowed by the outbound policy.
- An entry with an empty `to` (`t10`, data) gives that zone's VMs an outbound
  DROP policy.

## Never

- Edit `firewall.tf` by hand.
- Add a rule that has no line in the `transit` block.
- Give `data` an egress rule; its `to:` is empty on purpose.
- Add a rule towards `mgmt` from another zone. Only `t12`, inside `mgmt`.

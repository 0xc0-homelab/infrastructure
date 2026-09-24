---
name: firewall-matrix
description: Opens, closes or reviews a port between zones, or towards the node, by editing the transit matrix in environments/prod/terraform.tfvars. Use whenever traffic between zones changes, or a firewall rule needs explaining.
---

# Changing the zone firewall

The `transit` list in `environments/prod/terraform.tfvars` is every flow the
firewall allows; anything not in it is denied. The `zone-firewall` module turns
it into rules: nothing is generated into a file, and no rule is ever written as
a resource by hand.

The flow is always: edit the matrix → plan → read every changed rule.

## Procedure

1. Edit `transit`: change an entry, or add one. An entry is
   `{ from, to, ports, note }`, all TCP. `from` and `to` are zone aliases,
   `node` or `internet`. `note` is plain ASCII and says why.
2. If the change is towards the node from `mgmt` or `ci`, check that its ports
   are in `node_firewall.admin_ports`: anything else is dropped from the node
   rule on purpose.
3. `scripts/tofu prod plan` and read every changed rule. Each rule's comment is
   `<from> -> <to>: <note>`.
4. Update the explanation in `docs/zones.md` if the change alters what it says.
5. Open the PR. `network-reviewer` checks the invariants; the validations in
   `variables.tf` already refuse the ones they can.

## What the module does

- An entry towards a zone becomes an inbound rule in that zone's security group
  (`zone-<vnet>`), sourced from the `from` zone's CIDR.
- An entry towards `node` becomes a node rule. From an admin zone (`mgmt`,
  `ci`) only its ports among `node_firewall.admin_ports` survive; from
  elsewhere, its ports as written.
- An entry towards `internet` is egress, allowed by the outbound policy.
- An entry with an empty `to` (data's) gives that zone's VMs an outbound DROP
  policy.

## Never

- Write a firewall rule as a resource outside the module.
- Give `data` a destination; its `to` is empty on purpose. The plan refuses it.
- Add an entry towards `mgmt` from another zone. The plan refuses it.
- Open the node to `internet`. The plan refuses it.

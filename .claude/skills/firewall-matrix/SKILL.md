---
name: firewall-matrix
description: Generates or updates firewall.tf from the transit matrix in docs/zones.md. Use it when a port between zones has to be opened, closed or reviewed, or when firewall.tf and the matrix may have diverged.
---

# Generating firewall.tf from the matrix

`docs/zones.md` is normative. `firewall.tf` is a derived artifact.
The flow is always: edit the matrix → regenerate → review the diff.

## Never

- Hand-edit `firewall.tf`.
- Add a rule that has no line in the `transit` block.
- Generate egress rules from `data` (its `to:` entry is empty on purpose).
- Generate ingress rules towards `mgmt`.

## Procedure

1. Read the `zones`, `aggregates`, `node`, `reserved` and `transit` blocks of
   `docs/zones.md`.
2. If the requested change is opening or closing a port, edit the matching
   `transit` entry **first**, or add a new one with the next free `id` (`t11`,
   `t12`, …) and its `note` explaining why.
3. Regenerate the whole `firewall.tf` from the matrix. No partial patching: the
   file is rewritten end to end so it always mirrors the matrix.
4. Run `tofu fmt` and `tofu validate`.
5. Show the diff and stop. The human runs the apply.

## Shape of the generated file

Fixed header:

```hcl
# GENERATED from docs/zones.md — do not edit by hand.
# To change a rule: edit the `transit` block of docs/zones.md
# and regenerate with the `firewall-matrix` skill.
```

One rule per (source, destination, port) triple, using the native Proxmox
firewall through `bpg/proxmox`. Every resource carries:

- The matrix `id` in the `comment`, with the note if it has one.
  Example: `comment = "t05 — NGINX towards apps and towards the cluster ingress"`
- `source` and `dest` as zone CIDRs, taken from `zones`, never hardcoded.
- Port ranges verbatim (`30000-32767`), not expanded.

After the transit rules, generate:

- The explicit egress deny from `data` (`t10`), with a comment.
- The node rules: `DROP` policy, every transit entry whose `to` includes
  `node` (today `t11`, 443 from the internet), and acceptance of 22 and 8006 only from the
  `control` aggregate (`10.10.0.0/22`).

## Final check

Before calling the result good, verify that every rule in `firewall.tf` traces
to an existing `id`, and that every `id` in the matrix has at least one rule.
A divergence in either direction is an error, not a warning.

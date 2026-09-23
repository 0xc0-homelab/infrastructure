---
name: packer-template
description: Builds and maintains Proxmox VM templates with Packer using the proxmox-iso builder — plugin pinning, cloud-init, qemu-guest-agent and the handoff to OpenTofu. Use when creating or updating a base image.
---

# Packer templates for Proxmox

> **Once `vm-ci` runs (end of phase 1).** The base template stays an official
> cloud image imported by OpenTofu (`modules/cloud-image-template`). Use Packer only for a
> template that must be baked: the CI runner, or a zone with no egress where a
> VM cannot install packages at first boot.

Packer produces the template; OpenTofu clones it. The split matters: anything
that belongs to a specific VM (its address, its hostname, its role) is
OpenTofu's and Ansible's job, never baked into the image.

A template derived from the Debian base uses the `proxmox-clone` builder, from
`github.com/hashicorp/packer-plugin-proxmox`: it clones the base template
(VMID 9000), and Ansible bakes the rest with the same roles the VMs use, through
their `install` entry point. `proxmox-iso` is only for a template that cannot
start from the base.

The build VM takes the address reserved under `build_vms` in `docs/zones.md`.
Packer injects its throwaway SSH key through cloud-init and reaches that
address directly, so the build does not wait on the guest agent.

Builds run in CI (`.github/workflows/packer.yml`): `validate` on every PR, and
`build` on a merge to `main`, on `vm-ci`, after the operator approves
`production`. A template version that already exists is skipped: bumping
`version` and `vm_id` in `<name>.auto.pkrvars.hcl` is what rebuilds.
Locally: `scripts/packer <name> validate`.
The HashiCorp Packer skills in this session target AWS, Azure and HCP — none of
them applies here. Do not follow `amazon-ebs` patterns.

## What goes in the image, and what does not

In: the base OS, `qemu-guest-agent`, `cloud-init`, the SSH hardening that is
identical everywhere, and the package baseline.

Out: IP addresses, hostnames, SSH authorized keys for a specific operator,
anything zone-specific, and every secret. An image is cloned many times; a
secret baked into it is a secret you cannot rotate.

## Structure

```
packer/<template-name>/
  <name>.pkr.hcl             sources and build
  variables.pkr.hcl          variable declarations, no secret values
  <name>.auto.pkrvars.hcl    the version being built and its VMID
  playbook.yml               the roles baked in (install entry points)
  http/                      autoinstall / preseed, proxmox-iso only
```

## Required pieces

**Pin the plugin.** A `packer` block with `required_plugins`, version pinned
exactly — same rule as `mise.toml`, no ranges. An unpinned builder changes
under you between builds.

**`qemu_agent` must be enabled.** OpenTofu reads the VM's address back through
the guest agent. Without it the agent is missing in every cloned VM and the
`tofu plan` cannot resolve addresses. This is the single most common cause of a
template that builds fine and is useless afterwards.

**Cloud-init must be enabled** on the template, so OpenTofu can inject the
per-VM configuration at clone time.

**`boot_command` and `http_directory`** (`proxmox-iso` only) serve the
autoinstall or preseed file to the installer. This is the fiddliest part;
expect to iterate.

**Credentials come from the environment or SOPS**, never from the `.pkr.hcl`.
Declare them as variables with `sensitive = true` and no default.

Check every field name against the `packer-plugin-proxmox` documentation. The
plugin's attribute names differ from the cloud builders and are easy to
misremember. Do not invent syntax; if unsure, look it up and say so.

## Versioning

The template name carries a version or a date, and the old template is not
deleted while a VM still references it. Rolling a template that live VMs were
cloned from is not reversible.

A template version bump is its own commit: `chore(packer): bump debian base to
<version>`.

## Procedure

1. Confirm the template belongs to the current phase (`CLAUDE.md`).
2. Write `variables.pkr.hcl` first: decide the inputs before the build.
3. Write the source and build blocks, plugin version pinned.
4. `packer fmt` and `packer validate`.
5. Build, and watch the console during the autoinstall stage.
6. Verify on the resulting template, before handing it to OpenTofu:
   qemu-guest-agent enabled, cloud-init enabled, no secret in the image, no
   leftover host keys or machine-id that would be cloned into every VM.
7. Show the result and stop.

## Check before calling it done

- Plugin version pinned exactly.
- `qemu_agent` and cloud-init both enabled.
- No secret, no per-VM value, no operator-specific key in the image.
- `/etc/machine-id` and SSH host keys cleared so clones do not collide.
- The old template still exists if anything references it.

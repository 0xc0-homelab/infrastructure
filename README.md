# infrastructure

OpenTofu, Packer and Ansible for the 0xc0-homelab node: its SDN zones, its
firewall, and the VMs on it.

- **How it fits together:** [`docs/architecture.md`](docs/architecture.md)
- **The network:** decided in [`environments/prod/terraform.tfvars`](environments/prod/terraform.tfvars), explained in [`docs/zones.md`](docs/zones.md)
- **Why it is this way:** [`workspace/docs/design.md`](https://github.com/0xc0-homelab/workspace/blob/main/docs/design.md)

```
environments/prod/     the root for the node — only calls modules
modules/<name>/        the resources
scripts/tofu           runs tofu on an environment, secrets decrypted in env
scripts/ansible        runs ansible-playbook with the tunnel token in env
ansible/               what runs inside the VMs: inventory, playbooks, roles
secrets/               SOPS-encrypted, to the operator and this repo's CI key
docs/                  architecture and the zone matrix
```

## Running it

Tools come from `mise.toml`. Secrets never touch disk in plaintext:

```
scripts/tofu prod init
scripts/tofu prod plan
```

Every change goes through a PR linked to an issue. `plan` comments the plan on
the PR; `apply` runs after merge and waits for the operator's approval. The
conventions are the org's, in
[`0xc0-homelab/.github`](https://github.com/0xc0-homelab/.github#conventions).

The Traefik, RustFS and PBS running on the node are **not** managed here.

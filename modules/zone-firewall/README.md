# zone-firewall

The zone firewall, filtered on each guest's NIC.

- One **security group per zone** (`zone-<vnet>`) with its inbound rules. The
  rules come from `docs/zones.md` through `scripts/generate-firewall` into
  `environments/prod/firewall.tf`; they are never written by hand.
- Every VM gets its **own firewall on**: inbound DROP except its zone's group;
  outbound ACCEPT, except zones that initiate nothing (`data`), which get DROP.
- `enabled` is the **datacenter master switch**. With it off, none of this is
  enforced.
- The **host's firewall stays off** — its default DROP would cut Traefik's 443.
  Node-bound rules come with infrastructure#13.

Why on the NIC and not on the VNet: the node runs `pve-firewall` (iptables).
VNet-level (forward) rules only exist in the nftables `proxmox-firewall`, which
the Proxmox docs call a tech preview not suited for production.

Docker on the node sets iptables `FORWARD` to DROP. Once `pve-firewall` loads
bridge netfilter, a VM **without** its own firewall has all its traffic dropped
there — which is why every VM has one before the master switch is turned on.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.12 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | 0.114.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.114.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [proxmox_node_firewall.main](https://registry.terraform.io/providers/bpg/proxmox/0.114.0/docs/resources/node_firewall) | resource |
| [proxmox_virtual_environment_cluster_firewall.main](https://registry.terraform.io/providers/bpg/proxmox/0.114.0/docs/resources/virtual_environment_cluster_firewall) | resource |
| [proxmox_virtual_environment_cluster_firewall_security_group.main](https://registry.terraform.io/providers/bpg/proxmox/0.114.0/docs/resources/virtual_environment_cluster_firewall_security_group) | resource |
| [proxmox_virtual_environment_firewall_alias.local_network](https://registry.terraform.io/providers/bpg/proxmox/0.114.0/docs/resources/virtual_environment_firewall_alias) | resource |
| [proxmox_virtual_environment_firewall_options.main](https://registry.terraform.io/providers/bpg/proxmox/0.114.0/docs/resources/virtual_environment_firewall_options) | resource |
| [proxmox_virtual_environment_firewall_rules.main](https://registry.terraform.io/providers/bpg/proxmox/0.114.0/docs/resources/virtual_environment_firewall_rules) | resource |
| [proxmox_virtual_environment_firewall_rules.node](https://registry.terraform.io/providers/bpg/proxmox/0.114.0/docs/resources/virtual_environment_firewall_rules) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | The datacenter firewall's master switch. Nothing below is enforced while it is false. | `bool` | n/a | yes |
| <a name="input_no_egress"></a> [no\_egress](#input\_no\_egress) | VNets whose VMs initiate nothing: outbound policy DROP. | `list(string)` | n/a | yes |
| <a name="input_node_enabled"></a> [node\_enabled](#input\_node\_enabled) | The node's own firewall: DROP on everything but node\_rules. Needs `enabled` too. | `bool` | n/a | yes |
| <a name="input_node_name"></a> [node\_name](#input\_node\_name) | Proxmox node. | `string` | n/a | yes |
| <a name="input_node_rules"></a> [node\_rules](#input\_node\_rules) | Inbound rules of the node, generated from docs/zones.md into firewall.tf. An empty source is any. | <pre>list(object({<br/>    source  = string<br/>    dport   = string<br/>    comment = string<br/>  }))</pre> | n/a | yes |
| <a name="input_rules"></a> [rules](#input\_rules) | Inbound rules per zone, keyed by VNet — generated from docs/zones.md into firewall.tf. | <pre>map(list(object({<br/>    source  = string<br/>    dport   = string<br/>    comment = string<br/>  })))</pre> | n/a | yes |
| <a name="input_vms"></a> [vms](#input\_vms) | Every VM, with its VMID and VNet. | <pre>map(object({<br/>    vm_id = number<br/>    vnet  = string<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_groups"></a> [groups](#output\_groups) | Security group per zone. |
<!-- END_TF_DOCS -->

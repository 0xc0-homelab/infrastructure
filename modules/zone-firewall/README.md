# zone-firewall

The zone firewall, filtered on each guest's NIC, and the node's own firewall.
Its input is the transit matrix (`transit` in `environments/prod/terraform.tfvars`);
the module computes every rule from it, and none is written by hand.

- One **security group per zone** (`zone-<vnet>`) with its inbound rules, one
  per matrix entry towards that zone, commented `<from> -> <to>: <note>`.
- Every VM gets its **own firewall on**: inbound DROP except its zone's group;
  outbound ACCEPT, except zones that initiate nothing (`data`), which get DROP.
  A VM's options and rules are **recreated whenever the VM is**: Proxmox deletes
  them with the VM, and the provider cannot move rules to a new VMID in place.
  The trigger is the VM's NIC MAC, new on every creation.
- The **node** gets the matrix entries towards `node`: from an admin zone only
  its `admin_ports`, from elsewhere the entry's ports. Its DROP is switched on
  only after its rules exist. `local_network` points at loopback, so Proxmox
  grants no implicit admin access to the network it detects.
- `enabled` is the **datacenter master switch**; `node_enabled`, the node's.
  With the first off, nothing is enforced.

Why on the NIC and not on the VNet: the node runs `pve-firewall` (iptables).
VNet-level (forward) rules only exist in the nftables `proxmox-firewall`, which
the Proxmox docs call a tech preview.

The node's `FORWARD` policy must be ACCEPT, as Proxmox expects: Docker on the
node runs with `ip-forward-no-drop` (`docs/architecture.md`, The node). With
Docker's default DROP, every VM loses its egress once the datacenter firewall
is on.

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
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

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
| [terraform_data.vm](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | The datacenter firewall's master switch. Nothing below is enforced while it is false. | `bool` | n/a | yes |
| <a name="input_node_admin"></a> [node\_admin](#input\_node\_admin) | From admin\_zones the node admits only admin\_ports; from anywhere else, an entry's ports as written. | <pre>object({<br/>    admin_zones = list(string)<br/>    admin_ports = list(string)<br/>  })</pre> | n/a | yes |
| <a name="input_node_enabled"></a> [node\_enabled](#input\_node\_enabled) | The node's own firewall: DROP on everything but its rules. Needs `enabled` too. | `bool` | n/a | yes |
| <a name="input_node_name"></a> [node\_name](#input\_node\_name) | Proxmox node. | `string` | n/a | yes |
| <a name="input_transit"></a> [transit](#input\_transit) | The transit matrix, validated by the root. Each entry becomes rules commented "<from> -> <to>: <note>". | <pre>list(object({<br/>    from  = string<br/>    to    = list(string)<br/>    ports = list(string)<br/>    note  = string<br/>  }))</pre> | n/a | yes |
| <a name="input_vms"></a> [vms](#input\_vms) | Every VM, with its VMID, VNet and NIC MAC. A new MAC means the VM was recreated. | <pre>map(object({<br/>    vm_id = number<br/>    vnet  = string<br/>    mac   = string<br/>  }))</pre> | n/a | yes |
| <a name="input_zones"></a> [zones](#input\_zones) | Every zone, keyed by VNet ID: its alias (the name the transit matrix uses) and CIDR. | <pre>map(object({<br/>    alias = string<br/>    cidr  = string<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_groups"></a> [groups](#output\_groups) | Security group per zone. |
<!-- END_TF_DOCS -->

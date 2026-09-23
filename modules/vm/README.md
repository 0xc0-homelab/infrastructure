# vm

A VM cloned from a template in `modules/cloud-image-template`, configured by
cloud-init through the Proxmox API only — user, SSH keys, static address, DNS.
No SSH from the provider to the node, and no snippets.

- The NIC has the Proxmox firewall **on**: zone rules only apply to a guest
  whose NIC has it.
- The guest agent is off until Ansible installs it in the guest.
- VMIDs 100-8999; templates keep 9000-9099.

Everything inside the guest after first boot is Ansible's job.

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
| [proxmox_virtual_environment_vm.main](https://registry.terraform.io/providers/bpg/proxmox/0.114.0/docs/resources/virtual_environment_vm) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cores"></a> [cores](#input\_cores) | vCPUs. | `number` | `1` | no |
| <a name="input_datastore_id"></a> [datastore\_id](#input\_datastore\_id) | Datastore for the disk and the cloud-init drive. | `string` | n/a | yes |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Root disk size. It can grow from the template's, never shrink. | `number` | `8` | no |
| <a name="input_dns_servers"></a> [dns\_servers](#input\_dns\_servers) | Resolvers written by cloud-init. | `list(string)` | n/a | yes |
| <a name="input_ipv4_address"></a> [ipv4\_address](#input\_ipv4\_address) | Static address in CIDR notation, inside the zone, e.g. 10.10.0.10/24. | `string` | n/a | yes |
| <a name="input_ipv4_gateway"></a> [ipv4\_gateway](#input\_ipv4\_gateway) | Gateway: the host, on the zone's .1. | `string` | n/a | yes |
| <a name="input_memory_mb"></a> [memory\_mb](#input\_memory\_mb) | Memory in MB. | `number` | `1024` | no |
| <a name="input_name"></a> [name](#input\_name) | VM name, e.g. vm-access. | `string` | n/a | yes |
| <a name="input_node_name"></a> [node\_name](#input\_node\_name) | Proxmox node. | `string` | n/a | yes |
| <a name="input_ssh_public_keys"></a> [ssh\_public\_keys](#input\_ssh\_public\_keys) | Public keys authorised for username. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Proxmox tags. | `list(string)` | `[]` | no |
| <a name="input_template_vm_id"></a> [template\_vm\_id](#input\_template\_vm\_id) | VMID of the template to clone. | `number` | n/a | yes |
| <a name="input_username"></a> [username](#input\_username) | Admin user created by cloud-init; SSH keys only, no password. | `string` | n/a | yes |
| <a name="input_vm_id"></a> [vm\_id](#input\_vm\_id) | VMID. VMs use 100-8999; 9000-9099 is for templates. | `number` | n/a | yes |
| <a name="input_vnet"></a> [vnet](#input\_vnet) | SDN VNet the VM attaches to — its zone. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ipv4_address"></a> [ipv4\_address](#output\_ipv4\_address) | Static address, without the prefix length. |
| <a name="output_vm_id"></a> [vm\_id](#output\_vm\_id) | VMID. |
<!-- END_TF_DOCS -->

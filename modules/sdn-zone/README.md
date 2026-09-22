# sdn-zone

One Proxmox SDN **Simple** zone, with a VNet and a subnet per homelab zone.

- The gateway of every subnet is the **host**, on the first address of its
  CIDR — computed, not an input, so it cannot drift from the design.
- `snat` per VNet: egress through the node's public interface. Off for `data`,
  which initiates nothing.
- VNet IDs are limited by Proxmox to 8 letters and digits; the full zone name
  goes in `alias`.
- Two appliers, as the provider recommends: `changes` is replaced — and so
  re-applies the SDN config — whenever a zone, VNet or subnet changes;
  `finalizer` goes last on destroy. Without them, changes stay pending in
  Proxmox.

Uses the `proxmox_sdn_*` resources; the `proxmox_virtual_environment_sdn_*`
ones are deprecated.

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
| [proxmox_sdn_applier.changes](https://registry.terraform.io/providers/bpg/proxmox/0.114.0/docs/resources/sdn_applier) | resource |
| [proxmox_sdn_applier.finalizer](https://registry.terraform.io/providers/bpg/proxmox/0.114.0/docs/resources/sdn_applier) | resource |
| [proxmox_sdn_subnet.main](https://registry.terraform.io/providers/bpg/proxmox/0.114.0/docs/resources/sdn_subnet) | resource |
| [proxmox_sdn_vnet.main](https://registry.terraform.io/providers/bpg/proxmox/0.114.0/docs/resources/sdn_vnet) | resource |
| [proxmox_sdn_zone_simple.main](https://registry.terraform.io/providers/bpg/proxmox/0.114.0/docs/resources/sdn_zone_simple) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_nodes"></a> [nodes](#input\_nodes) | Proxmox nodes the zone and its VNets are deployed on. | `list(string)` | n/a | yes |
| <a name="input_vnets"></a> [vnets](#input\_vnets) | One VNet per homelab zone, keyed by VNet ID (letters and digits, up to 8 characters). The gateway is always the host, on the first address of the CIDR. | <pre>map(object({<br/>    alias = string<br/>    cidr  = string<br/>    snat  = bool<br/>  }))</pre> | n/a | yes |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | SDN zone ID. Proxmox allows letters and digits only, up to 8 characters. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_vnets"></a> [vnets](#output\_vnets) | Per VNet ID: its CIDR and gateway, for attaching guests. |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | SDN zone ID. |
<!-- END_TF_DOCS -->

# cloud-image-template

A Proxmox VM template made straight from a distribution's official cloud image,
entirely through the Proxmox API: no SSH to the node, and no build VM.

- Proxmox downloads the image and verifies its SHA-512 itself. The URL must be
  a pinned, dated build; `latest` links are rejected, because they change under
  you.
- The disk is imported with `import_from`, which needs the `import` content type
  on the datastore. The alternative, `file_id`, makes the provider SSH into the
  node, which this repo does not allow.
- No guest agent in the image: it is installed on each VM after first boot.
- Everything per VM — user, SSH key, address — comes from cloud-init on each
  clone.

Templates use VMIDs 9000-9099.

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
| [proxmox_download_file.main](https://registry.terraform.io/providers/bpg/proxmox/0.114.0/docs/resources/download_file) | resource |
| [proxmox_virtual_environment_vm.main](https://registry.terraform.io/providers/bpg/proxmox/0.114.0/docs/resources/virtual_environment_vm) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_bridge"></a> [bridge](#input\_bridge) | Default network for clones, which normally override it with their own zone VNet. | `string` | n/a | yes |
| <a name="input_datastore_id"></a> [datastore\_id](#input\_datastore\_id) | Datastore for the downloaded image and the template disk. It must allow the import content type. | `string` | n/a | yes |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Size of the template disk. Clones can grow it, never shrink it. | `number` | `8` | no |
| <a name="input_image_checksum"></a> [image\_checksum](#input\_image\_checksum) | SHA-512 of the image, as published by the distribution. | `string` | n/a | yes |
| <a name="input_image_url"></a> [image\_url](#input\_image\_url) | URL of an uncompressed cloud image (qcow2). Pin a dated build, never a 'latest' link. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Template name in Proxmox. | `string` | n/a | yes |
| <a name="input_node_name"></a> [node\_name](#input\_node\_name) | Proxmox node that holds the template. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_name"></a> [name](#output\_name) | Template name. |
| <a name="output_vm_id"></a> [vm\_id](#output\_vm\_id) | VMID of the template, for clones. |
<!-- END_TF_DOCS -->

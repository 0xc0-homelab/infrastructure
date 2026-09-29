# backup-job

A backup job on the node: the listed VMs, whole, to a PBS storage.

- The mode is `snapshot`, so the guests keep running. Every disk goes in,
  data disks included: that is how the RKE2 servers' Longhorn volumes are
  backed up.
- `retention` becomes the job's prune settings (`keep-daily`, `keep-weekly`,
  and so on). PBS applies them per guest after each run.
- The PBS storage itself (the datastore on the Storage Box) is configured on
  the node, outside this repo.

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
| [proxmox_backup_job.main](https://registry.terraform.io/providers/bpg/proxmox/0.114.0/docs/resources/backup_job) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_id"></a> [id](#input\_id) | The job's identifier in Proxmox. | `string` | n/a | yes |
| <a name="input_node_name"></a> [node\_name](#input\_node\_name) | Proxmox node the job runs on. | `string` | n/a | yes |
| <a name="input_retention"></a> [retention](#input\_retention) | How many backups PBS keeps per guest, by period. 0 keeps none of that period. | <pre>object({<br/>    last    = optional(number, 0)<br/>    daily   = optional(number, 0)<br/>    weekly  = optional(number, 0)<br/>    monthly = optional(number, 0)<br/>    yearly  = optional(number, 0)<br/>  })</pre> | n/a | yes |
| <a name="input_schedule"></a> [schedule](#input\_schedule) | When the job runs, as a Proxmox calendar event (e.g. "03:00" for daily at 03:00). | `string` | n/a | yes |
| <a name="input_storage"></a> [storage](#input\_storage) | Backup storage the job writes to: a PBS storage already configured on the node. | `string` | n/a | yes |
| <a name="input_vm_ids"></a> [vm\_ids](#input\_vm\_ids) | VMIDs of the guests the job backs up. | `list(number)` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_id"></a> [id](#output\_id) | The job's identifier in Proxmox. |
<!-- END_TF_DOCS -->

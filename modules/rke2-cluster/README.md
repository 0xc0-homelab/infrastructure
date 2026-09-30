# rke2-cluster

The RKE2 cluster and its load balancer, created together in one zone: the
RKE2 servers (control plane, etcd and workloads on every one) and the HAProxy
+ keepalived pair in front of them. Each machine is a `vm` module, with its
firewall and `prevent_destroy`.

The VIP belongs to keepalived and is set up by Ansible, like everything
inside the guests (`playbooks/cluster.yml`).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.12 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | 0.114.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_agents"></a> [agents](#module\_agents) | ../vm | n/a |
| <a name="module_load_balancers"></a> [load\_balancers](#module\_load\_balancers) | ../vm | n/a |
| <a name="module_servers"></a> [servers](#module\_servers) | ../vm | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_agents"></a> [agents](#input\_agents) | The RKE2 agents — workloads only, no control plane or etcd: the template, the size, the data disks, and each VM's address. An empty nodes map for none. | <pre>object({<br/>    template_vm_id = number<br/>    cpu_type       = string<br/>    cores          = number<br/>    memory_mb      = number<br/>    disk_size_gb   = number<br/>    data_disks_gb  = list(number)<br/>    nodes = map(object({<br/>      ip      = string<br/>      rebuild = number<br/>    }))<br/>  })</pre> | n/a | yes |
| <a name="input_cidr"></a> [cidr](#input\_cidr) | The zone's CIDR: every address is inside it, and the host's .1 is the gateway. | `string` | n/a | yes |
| <a name="input_datastore_id"></a> [datastore\_id](#input\_datastore\_id) | Datastore for the disks and the cloud-init drives. | `string` | n/a | yes |
| <a name="input_dns_servers"></a> [dns\_servers](#input\_dns\_servers) | Resolvers written by cloud-init. | `list(string)` | n/a | yes |
| <a name="input_load_balancers"></a> [load\_balancers](#input\_load\_balancers) | The HAProxy + keepalived pair: the template to clone, the size, and each VM's address. | <pre>object({<br/>    template_vm_id = number<br/>    cores          = number<br/>    memory_mb      = number<br/>    disk_size_gb   = number<br/>    nodes = map(object({<br/>      ip      = string<br/>      rebuild = number<br/>    }))<br/>  })</pre> | n/a | yes |
| <a name="input_node_name"></a> [node\_name](#input\_node\_name) | Proxmox node. | `string` | n/a | yes |
| <a name="input_servers"></a> [servers](#input\_servers) | The RKE2 servers — control plane, etcd and workloads together: the template, the size, the data disks, and each VM's address. | <pre>object({<br/>    template_vm_id = number<br/>    cpu_type       = string<br/>    cores          = number<br/>    memory_mb      = number<br/>    disk_size_gb   = number<br/>    data_disks_gb  = list(number)<br/>    nodes = map(object({<br/>      ip      = string<br/>      rebuild = number<br/>    }))<br/>  })</pre> | n/a | yes |
| <a name="input_ssh_public_keys"></a> [ssh\_public\_keys](#input\_ssh\_public\_keys) | Public keys authorised for username. | `list(string)` | n/a | yes |
| <a name="input_username"></a> [username](#input\_username) | Admin user created by cloud-init; SSH keys only, no password. | `string` | n/a | yes |
| <a name="input_vnet"></a> [vnet](#input\_vnet) | SDN VNet the whole cluster attaches to — its zone. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_agents"></a> [agents](#output\_agents) | The RKE2 agents' addresses, by name. |
| <a name="output_load_balancers"></a> [load\_balancers](#output\_load\_balancers) | The load balancers' addresses, by name. |
| <a name="output_servers"></a> [servers](#output\_servers) | The RKE2 servers' addresses, by name. |
| <a name="output_vms"></a> [vms](#output\_vms) | Every VM of the cluster, load balancers, servers and agents, with its VMID, VNet and NIC MAC: the zone firewall's and the backup job's input. |
<!-- END_TF_DOCS -->

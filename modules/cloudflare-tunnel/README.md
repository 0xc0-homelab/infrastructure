# cloudflare-tunnel

A Cloudflare Tunnel configured from Cloudflare (`config_src = "cloudflare"`),
so the VM running its connector needs no config file — only the token.

- `routes` are private networks carried by the tunnel for WARP clients: the
  admin path into the homelab.
- `token` is a sensitive output. It reaches the connector through Ansible,
  straight from `tofu output`, never through a file.

Public hostnames (ingress) are added when the edge tunnel needs them.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.12 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | 5.25.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | 5.25.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [cloudflare_zero_trust_tunnel_cloudflared.main](https://registry.terraform.io/providers/cloudflare/cloudflare/5.25.0/docs/resources/zero_trust_tunnel_cloudflared) | resource |
| [cloudflare_zero_trust_tunnel_cloudflared_route.main](https://registry.terraform.io/providers/cloudflare/cloudflare/5.25.0/docs/resources/zero_trust_tunnel_cloudflared_route) | resource |
| [cloudflare_zero_trust_tunnel_cloudflared_token.main](https://registry.terraform.io/providers/cloudflare/cloudflare/5.25.0/docs/data-sources/zero_trust_tunnel_cloudflared_token) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Cloudflare account ID. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Tunnel name, usually the VM that runs its connector. | `string` | n/a | yes |
| <a name="input_routes"></a> [routes](#input\_routes) | Private networks, in CIDR notation, routed through this tunnel for WARP clients. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_token"></a> [token](#output\_token) | Connector token for cloudflared on the VM. Never write it to disk in plaintext. |
| <a name="output_tunnel_id"></a> [tunnel\_id](#output\_tunnel\_id) | Tunnel UUID. |
<!-- END_TF_DOCS -->

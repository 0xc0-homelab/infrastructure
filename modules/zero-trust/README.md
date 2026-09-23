# zero-trust

The account-wide Zero Trust singletons.

- **Organization** — its name and team domain (`<team_name>.cloudflareaccess.com`).
  The provider has no import for it; its create is an update, so it adopts the
  organization that exists once Zero Trust is enabled.
- **Default device profile** — split tunnels in **Include** mode: WARP carries
  only `include_networks`. Managing it means owning the whole profile; anything
  not declared keeps Cloudflare's default. The profile always exists, so the
  root imports it rather than creating it.
- **Device enrollment** — the `warp` Access application, gated by one policy.
  Only `allowed_emails` can enroll a device, and so reach the private networks.

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
| [cloudflare_zero_trust_access_application.main](https://registry.terraform.io/providers/cloudflare/cloudflare/5.25.0/docs/resources/zero_trust_access_application) | resource |
| [cloudflare_zero_trust_access_policy.main](https://registry.terraform.io/providers/cloudflare/cloudflare/5.25.0/docs/resources/zero_trust_access_policy) | resource |
| [cloudflare_zero_trust_device_default_profile.main](https://registry.terraform.io/providers/cloudflare/cloudflare/5.25.0/docs/resources/zero_trust_device_default_profile) | resource |
| [cloudflare_zero_trust_organization.main](https://registry.terraform.io/providers/cloudflare/cloudflare/5.25.0/docs/resources/zero_trust_organization) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Cloudflare account ID. | `string` | n/a | yes |
| <a name="input_allowed_emails"></a> [allowed\_emails](#input\_allowed\_emails) | Who may enroll a device into the organization's WARP — and so reach the private networks. | `list(string)` | n/a | yes |
| <a name="input_include_networks"></a> [include\_networks](#input\_include\_networks) | The only networks WARP carries (split tunnels in Include mode). Everything else stays off the tunnel. | `list(string)` | n/a | yes |
| <a name="input_team_name"></a> [team\_name](#input\_team\_name) | Zero Trust team name. Also the team domain: <team\_name>.cloudflareaccess.com. | `string` | n/a | yes |
| <a name="input_tunnel_protocol"></a> [tunnel\_protocol](#input\_tunnel\_protocol) | WARP tunnel protocol. MASQUE is the account's current setting. | `string` | `"masque"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_team_domain"></a> [team\_domain](#output\_team\_domain) | Zero Trust team domain, used when enrolling a WARP client. |
<!-- END_TF_DOCS -->

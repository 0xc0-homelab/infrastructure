# email-destinations

A Cloudflare account's Email Routing destination addresses. They belong to the
account, not to a zone: every zone of the account forwards to the same ones,
so each mailbox exists once per account, here. `email-routing` builds each
zone's rules and catch-all on top of them.

Cloudflare mails every new destination a confirmation link. Until it is
clicked, Cloudflare refuses rules towards it; `email-routing` creates a rule
only once its destination is verified, so the apply after the click adds it.

The API token needs Email Routing Addresses, Edit, on the account.

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
| [cloudflare_email_routing_address.main](https://registry.terraform.io/providers/cloudflare/cloudflare/5.25.0/docs/resources/email_routing_address) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Cloudflare account the destinations belong to. | `string` | n/a | yes |
| <a name="input_emails"></a> [emails](#input\_emails) | Mailboxes mail is forwarded to, by a name of the caller's choosing. | `map(string)` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->

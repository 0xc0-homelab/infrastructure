# email-routing

Cloudflare Email Routing for one zone: mail to an address in the zone is
forwarded to a mailbox elsewhere. There is no mailbox here and nothing is sent.

- **Enabled for the zone** (`cloudflare_email_routing_dns`): Cloudflare adds
  its MX and SPF records. A zone with MX records of its own refuses it.
- **Destinations**: the mailboxes, by a name, in the zone's account (found
  from the zone). Cloudflare mails each one a confirmation link on creation;
  forwarding to it works once it is clicked. A zone in another account needs
  its own confirmation for the same mailbox.
- **Rules**: one per forwarded address, `to` matcher, forward action, keyed
  by a hash of the address so no address shows in a plan.
- **Catch-all**: optional, every other address of the zone to one
  destination. Without one, the zone's catch-all stays as Cloudflare has it.

The API token needs Email Routing Addresses (account), Email Routing Rules
(zone) and Zone Settings (zone), all Edit, in every account and zone it is
used for. Nothing that exists already is adopted: a rule or a destination made
by hand is removed first, or imported.

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
| [cloudflare_email_routing_catch_all.main](https://registry.terraform.io/providers/cloudflare/cloudflare/5.25.0/docs/resources/email_routing_catch_all) | resource |
| [cloudflare_email_routing_dns.main](https://registry.terraform.io/providers/cloudflare/cloudflare/5.25.0/docs/resources/email_routing_dns) | resource |
| [cloudflare_email_routing_rule.main](https://registry.terraform.io/providers/cloudflare/cloudflare/5.25.0/docs/resources/email_routing_rule) | resource |
| [cloudflare_zone.main](https://registry.terraform.io/providers/cloudflare/cloudflare/5.25.0/docs/data-sources/zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_catch_all"></a> [catch\_all](#input\_catch\_all) | Name of the destination mail to any other address of the zone goes to (a key of destinations). null leaves the zone's catch-all as Cloudflare has it, unmanaged. | `string` | `null` | no |
| <a name="input_destinations"></a> [destinations](#input\_destinations) | Mailboxes mail is forwarded to, by a name of the caller's choosing. Each must be verified once per account, from Cloudflare's confirmation mail, before forwarding to it works. | `map(string)` | n/a | yes |
| <a name="input_forwards"></a> [forwards](#input\_forwards) | Address in the zone => name of the destination it forwards to (a key of destinations). Sensitive: the addresses never show in a plan. | `map(string)` | n/a | yes |
| <a name="input_zone_name"></a> [zone\_name](#input\_zone\_name) | Zone that receives the mail, e.g. 0xc0.cc. Its account, found from it, holds the destination addresses. | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->

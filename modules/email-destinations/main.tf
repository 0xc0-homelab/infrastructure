resource "cloudflare_email_routing_address" "main" {
  for_each = toset(nonsensitive(keys(var.emails)))

  account_id = var.account_id
  email      = var.emails[each.key]
}

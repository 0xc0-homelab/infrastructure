# A Cloudflare account's Email Routing destinations: they belong to the
# account, so zones of the same account share them, and each exists once.
# Cloudflare mails every new one a confirmation link; a zone's rules use it
# once it is clicked (email-routing).
resource "cloudflare_email_routing_address" "main" {
  for_each = toset(nonsensitive(keys(var.emails)))

  account_id = var.account_id
  email      = var.emails[each.key]
}

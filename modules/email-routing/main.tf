# Found by name in whichever account holds it: the zones are in more than
# one, and the token reaches them all.
data "cloudflare_zone" "main" {
  filter = {
    name = var.zone_name
  }
}

locals {
  account_id = data.cloudflare_zone.main.account.id
}

# Turns Email Routing on for the zone: Cloudflare adds its MX and SPF records.
resource "cloudflare_email_routing_dns" "main" {
  zone_id = data.cloudflare_zone.main.zone_id
}

# The destination mailboxes stay out of the plan's output: they are personal,
# and this repo is public. Their names are not secret.
resource "cloudflare_email_routing_address" "main" {
  for_each = toset(nonsensitive(keys(var.destinations)))

  account_id = local.account_id
  email      = var.destinations[each.key]
}

resource "cloudflare_email_routing_rule" "main" {
  for_each = var.forwards

  zone_id = data.cloudflare_zone.main.zone_id
  name    = "forward ${each.key}"
  enabled = true
  matchers = [{
    type  = "literal"
    field = "to"
    value = each.key
  }]
  actions = [{
    type  = "forward"
    value = [cloudflare_email_routing_address.main[each.value].email]
  }]

  depends_on = [cloudflare_email_routing_dns.main]
}

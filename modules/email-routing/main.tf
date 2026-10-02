# Found by name in whichever account holds it: the zones are in more than
# one, and the token reaches them all.
data "cloudflare_zone" "main" {
  filter = {
    name = var.zone_name
  }
}

locals {
  account_id = data.cloudflare_zone.main.account.id

  # Each rule is keyed by a hash of its address, so the addresses never show
  # in a plan (posted on the PR, in a public repo); the address itself stays
  # sensitive.
  rules = { for from, to in var.forwards : substr(sha256(from), 0, 16) => { from = from, to = to } }
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
  for_each = toset(nonsensitive(keys(local.rules)))

  zone_id = data.cloudflare_zone.main.zone_id
  name    = "forward ${local.rules[each.key].from}"
  enabled = true
  matchers = [{
    type  = "literal"
    field = "to"
    value = local.rules[each.key].from
  }]
  actions = [{
    type  = "forward"
    value = [cloudflare_email_routing_address.main[local.rules[each.key].to].email]
  }]

  depends_on = [cloudflare_email_routing_dns.main]
}

# Every other address of the zone, when the caller names a destination for
# it. Cloudflare keeps one catch-all per zone; managing it here owns it.
resource "cloudflare_email_routing_catch_all" "main" {
  count = nonsensitive(var.catch_all != null) ? 1 : 0

  zone_id  = data.cloudflare_zone.main.zone_id
  name     = "catch-all"
  enabled  = true
  matchers = [{ type = "all" }]
  actions = [{
    type  = "forward"
    value = [cloudflare_email_routing_address.main[var.catch_all].email]
  }]

  depends_on = [cloudflare_email_routing_dns.main]
}

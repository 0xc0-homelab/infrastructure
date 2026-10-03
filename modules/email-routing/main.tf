# The zones may be in more than one account.
data "cloudflare_zone" "main" {
  filter = {
    name = var.zone_name
  }
}

# Cloudflare refuses a rule towards an unconfirmed destination: the rule waits
# for the apply after the click.
data "cloudflare_email_routing_addresses" "verified" {
  account_id = local.account_id
  verified   = true
}

locals {
  account_id = data.cloudflare_zone.main.account.id
  verified   = toset([for a in data.cloudflare_email_routing_addresses.verified.result : lower(a.email)])

  # Keyed by a hash, so no address shows in a plan posted on a public PR.
  rules = { for from, to in var.forwards : substr(sha256(from), 0, 16) => { from = from, to = to } }
  ready = nonsensitive(toset([for k, r in local.rules : k if contains(local.verified, lower(var.destinations[r.to]))]))

  catch_all_ready = nonsensitive(var.catch_all != null && try(contains(local.verified, lower(var.destinations[var.catch_all])), false))
}

resource "cloudflare_email_routing_dns" "main" {
  zone_id = data.cloudflare_zone.main.zone_id
}

resource "cloudflare_email_routing_rule" "main" {
  for_each = local.ready

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
    value = [var.destinations[local.rules[each.key].to]]
  }]

  depends_on = [cloudflare_email_routing_dns.main]
}

resource "cloudflare_email_routing_catch_all" "main" {
  count = local.catch_all_ready ? 1 : 0

  zone_id  = data.cloudflare_zone.main.zone_id
  name     = "catch-all"
  enabled  = true
  matchers = [{ type = "all" }]
  actions = [{
    type  = "forward"
    value = [var.destinations[var.catch_all]]
  }]

  depends_on = [cloudflare_email_routing_dns.main]
}

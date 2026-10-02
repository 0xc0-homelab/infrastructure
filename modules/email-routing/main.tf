# Found by name in whichever account holds it: the zones may be in more than
# one, and the token reaches them all.
data "cloudflare_zone" "main" {
  filter = {
    name = var.zone_name
  }
}

# The account's destinations someone has confirmed. Cloudflare refuses a rule
# towards one that is not: a rule waits here until its destination is in this
# list, so a new destination never fails the apply, and the apply after the
# click adds its rules.
data "cloudflare_email_routing_addresses" "verified" {
  account_id = local.account_id
  verified   = true
}

locals {
  account_id = data.cloudflare_zone.main.account.id
  verified   = toset([for a in data.cloudflare_email_routing_addresses.verified.result : lower(a.email)])

  # Each rule is keyed by a hash of its address, so the addresses never show
  # in a plan (posted on the PR, in a public repo); the address itself stays
  # sensitive.
  rules = { for from, to in var.forwards : substr(sha256(from), 0, 16) => { from = from, to = to } }
  ready = nonsensitive(toset([for k, r in local.rules : k if contains(local.verified, lower(var.destinations[r.to]))]))

  catch_all_ready = nonsensitive(var.catch_all != null && try(contains(local.verified, lower(var.destinations[var.catch_all])), false))
}

# Turns Email Routing on for the zone: Cloudflare adds its MX and SPF records.
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

# Every other address of the zone, when the caller names a destination for
# it. Cloudflare keeps one catch-all per zone; managing it here owns it.
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

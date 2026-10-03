# The provider's create is an update: the organization always exists.
resource "cloudflare_zero_trust_organization" "main" {
  account_id  = var.account_id
  name        = var.team_name
  auth_domain = "${var.team_name}.cloudflareaccess.com"
}

# Setting include clears the default exclude list.
resource "cloudflare_zero_trust_device_default_profile" "main" {
  account_id = var.account_id
  include    = [for n in var.include_networks : { address = n, description = "${var.team_name} homelab" }]

  # Left out, the plan resets it to the provider default.
  tunnel_protocol = var.tunnel_protocol

  # Provider bug: policy_id is planned as unknown on every run. The
  # "Redundant ignore_changes element" warning is wrong: without this, every
  # plan shows a change. cloudflare/terraform-provider-cloudflare#6773
  lifecycle {
    ignore_changes = [policy_id]
  }
}

resource "cloudflare_zero_trust_access_policy" "main" {
  account_id = var.account_id
  name       = "${var.team_name} operator"
  decision   = "allow"
  include    = [for e in var.allowed_emails : { email = { email = e } }]
}

resource "cloudflare_zero_trust_access_application" "main" {
  account_id = var.account_id
  type       = "warp"
  name       = "Warp Login App"
  policies   = [{ id = cloudflare_zero_trust_access_policy.main.id, precedence = 1 }]
}

# The node's web front answers on its mgmt address too, so the public 443
# stays closed.
resource "cloudflare_zero_trust_gateway_policy" "main" {
  account_id  = var.account_id
  name        = "${var.team_name} private hostnames"
  description = "Resolves the node's web front to its address in mgmt, through WARP"
  action      = "override"
  enabled     = true
  filters     = ["dns"]
  traffic     = "dns.fqdn in {${join(" ", [for h in var.private_hostnames : "\"${h}\""])}}"

  rule_settings = {
    override_ips = [var.private_hostnames_ip]
  }
}

# The internal names have no public record: outside WARP they do not exist.
resource "cloudflare_zero_trust_gateway_policy" "internal" {
  count = length(var.internal_domains) > 0 ? 1 : 0

  account_id  = var.account_id
  name        = "${var.team_name} internal domains"
  description = "Resolves the internal domains to the internal VIP, through WARP"
  action      = "override"
  enabled     = true
  filters     = ["dns"]
  traffic     = join(" or ", [for d in var.internal_domains : "any(dns.domains[*] == \"${d}\")"])

  rule_settings = {
    override_ips = [var.internal_ip]
  }
}

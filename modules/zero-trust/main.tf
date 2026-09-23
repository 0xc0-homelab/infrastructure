# The account-wide Zero Trust pieces: the organization, the Default device
# profile, and who may enroll a device. Singletons — one of each per account.

# Adopted on create: the provider's create is an update, since the
# organization always exists once Zero Trust is enabled.
resource "cloudflare_zero_trust_organization" "main" {
  account_id  = var.account_id
  name        = var.team_name
  auth_domain = "${var.team_name}.cloudflareaccess.com"
}

# Include mode: WARP carries only the homelab, and the operator's other
# traffic goes out as usual. Setting include clears the default exclude list.
resource "cloudflare_zero_trust_device_default_profile" "main" {
  account_id = var.account_id
  include    = [for n in var.include_networks : { address = n, description = "${var.team_name} homelab" }]

  # Declared so OpenTofu does not reset it: left out, the plan clears it back
  # to the provider default.
  tunnel_protocol = var.tunnel_protocol
}

resource "cloudflare_zero_trust_access_policy" "main" {
  account_id = var.account_id
  name       = "${var.team_name} operator"
  decision   = "allow"
  include    = [for e in var.allowed_emails : { email = { email = e } }]
}

# The device enrollment application: only the policy above can enroll WARP.
resource "cloudflare_zero_trust_access_application" "main" {
  account_id = var.account_id
  type       = "warp"
  name       = "Warp Login App"
  policies   = [{ id = cloudflare_zero_trust_access_policy.main.id, precedence = 1 }]
}

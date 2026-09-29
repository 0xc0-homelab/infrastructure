# A Cloudflare Tunnel managed from Cloudflare (no config file on the VM), plus
# the private networks it carries for WARP clients, or the public hostnames it
# serves. The connector on the VM only needs the token.

resource "cloudflare_zero_trust_tunnel_cloudflared" "main" {
  account_id = var.account_id
  name       = var.name
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_route" "main" {
  for_each = toset(var.routes)

  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.main.id
  network    = each.value
  comment    = "${var.name}: ${each.value}"
}

# The public hostnames and where each goes. Anything else gets a 404 from
# Cloudflare's edge: a tunnel with no hostname exposes nothing. A tunnel that
# only carries private networks has no ingress at all.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "main" {
  count = var.ingress == null ? 0 : 1

  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.main.id

  config = {
    ingress = concat(
      [for rule in var.ingress : { hostname = rule.hostname, service = rule.service }],
      [{ service = "http_status:404" }],
    )
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "main" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.main.id
}

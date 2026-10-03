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

# Anything else gets a 404 from Cloudflare's edge.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "main" {
  count = var.ingress == null ? 0 : 1

  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.main.id

  config = {
    ingress = concat(
      # The request's host as SNI: one rule serves every name under a wildcard.
      [for rule in var.ingress : merge(
        { hostname = rule.hostname, service = rule.service },
        startswith(rule.service, "https://") ? { origin_request = { match_sn_ito_host = true } } : {},
      )],
      [{ service = "http_status:404" }],
    )
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "main" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.main.id
}

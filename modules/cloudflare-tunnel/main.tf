# A Cloudflare Tunnel managed from Cloudflare (no config file on the VM), plus
# the private networks it carries for WARP clients. The connector on the VM
# only needs the token.

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

data "cloudflare_zero_trust_tunnel_cloudflared_token" "main" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.main.id
}

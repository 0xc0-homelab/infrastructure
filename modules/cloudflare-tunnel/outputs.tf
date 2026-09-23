output "tunnel_id" {
  description = "Tunnel UUID."
  value       = cloudflare_zero_trust_tunnel_cloudflared.main.id
}

output "token" {
  description = "Connector token for cloudflared on the VM. Never write it to disk in plaintext."
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.main.token
  sensitive   = true
}

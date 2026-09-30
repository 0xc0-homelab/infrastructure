output "token" {
  description = "Connector token for cloudflared on the VM. Never write it to disk in plaintext."
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.main.token
  sensitive   = true
}

output "id" {
  description = "Tunnel ID. A public hostname is a CNAME to <id>.cfargotunnel.com."
  value       = cloudflare_zero_trust_tunnel_cloudflared.main.id
}

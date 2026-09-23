output "team_domain" {
  description = "Zero Trust team domain, used when enrolling a WARP client."
  value       = cloudflare_zero_trust_organization.main.auth_domain
}

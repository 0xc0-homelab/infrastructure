output "vm_access_tunnel_token" {
  description = "Connector token for cloudflared on vm-access. Read it with tofu output -raw, straight into Ansible; never to a file."
  value       = module.access_tunnel.token
  sensitive   = true
}

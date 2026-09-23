output "vm_addresses" {
  description = "Static address of every VM, for the Ansible inventory."
  value       = { for k, m in module.vms : k => m.ipv4_address }
}

output "vm_access_tunnel_token" {
  description = "Connector token for cloudflared on vm-access. Read it with tofu output -raw, straight into Ansible; never to a file."
  value       = module.access_tunnel.token
  sensitive   = true
}

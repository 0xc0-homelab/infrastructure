output "groups" {
  description = "Security group per zone."
  value       = { for vnet, g in proxmox_virtual_environment_cluster_firewall_security_group.main : vnet => g.name }
}

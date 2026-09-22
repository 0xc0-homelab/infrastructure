output "zone_id" {
  description = "SDN zone ID."
  value       = proxmox_sdn_zone_simple.main.id
}

output "vnets" {
  description = "Per VNet ID: its CIDR and gateway, for attaching guests."
  value = {
    for id, s in proxmox_sdn_subnet.main : id => {
      cidr    = s.cidr
      gateway = s.gateway
    }
  }
}

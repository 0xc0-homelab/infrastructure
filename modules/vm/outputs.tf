output "vm_id" {
  description = "VMID."
  value       = proxmox_virtual_environment_vm.main.vm_id
}

output "ipv4_address" {
  description = "Static address, without the prefix length."
  value       = split("/", var.ipv4_address)[0]
}

output "mac_address" {
  description = "MAC of the NIC. New on every creation, so it tells a recreated VM from the old one."
  value       = proxmox_virtual_environment_vm.main.network_device[0].mac_address
}

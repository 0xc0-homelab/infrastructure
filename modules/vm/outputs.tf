output "vm_id" {
  description = "VMID."
  value       = proxmox_virtual_environment_vm.main.vm_id
}

output "ipv4_address" {
  description = "Static address, without the prefix length."
  value       = split("/", var.ipv4_address)[0]
}

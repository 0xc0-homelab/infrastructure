output "vm_id" {
  description = "VMID of the template, for clones."
  value       = proxmox_virtual_environment_vm.main.vm_id
}

output "name" {
  description = "Template name."
  value       = proxmox_virtual_environment_vm.main.name
}

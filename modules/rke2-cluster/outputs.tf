output "vms" {
  description = "Every VM of the cluster, load balancers and servers, with its VMID, VNet and NIC MAC: the zone firewall's input."
  value = { for name, vm in merge(module.load_balancers, module.servers) : name => {
    vm_id = vm.vm_id
    vnet  = var.vnet
    mac   = vm.mac_address
  } }
}

output "load_balancers" {
  description = "The load balancers' addresses, by name."
  value       = { for name, vm in module.load_balancers : name => vm.ipv4_address }
}

output "servers" {
  description = "The RKE2 servers' addresses, by name."
  value       = { for name, vm in module.servers : name => vm.ipv4_address }
}

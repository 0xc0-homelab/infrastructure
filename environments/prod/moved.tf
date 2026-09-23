# vm-access became vm-access-01 (infrastructure#53). The VMID changed
# too, so the VM and its firewall are still recreated: these blocks only keep
# OpenTofu from reading the rename as one VM gone and an unrelated one added.
moved {
  from = module.vms["vm-access"]
  to   = module.vms["vm-access-01"]
}

moved {
  from = module.zone_firewall.proxmox_virtual_environment_firewall_options.main["vm-access"]
  to   = module.zone_firewall.proxmox_virtual_environment_firewall_options.main["vm-access-01"]
}

moved {
  from = module.zone_firewall.proxmox_virtual_environment_firewall_rules.main["vm-access"]
  to   = module.zone_firewall.proxmox_virtual_environment_firewall_rules.main["vm-access-01"]
}

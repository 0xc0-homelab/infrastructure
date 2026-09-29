# vm-ci became vm-ci-01 when vm-ci-02 joined it (#100): the same VM, renamed
# in place. Remove once applied.
moved {
  from = module.vms["vm-ci"]
  to   = module.vms["vm-ci-01"]
}

moved {
  from = module.zone_firewall.terraform_data.vm["vm-ci"]
  to   = module.zone_firewall.terraform_data.vm["vm-ci-01"]
}

moved {
  from = module.zone_firewall.proxmox_virtual_environment_firewall_options.main["vm-ci"]
  to   = module.zone_firewall.proxmox_virtual_environment_firewall_options.main["vm-ci-01"]
}

moved {
  from = module.zone_firewall.proxmox_virtual_environment_firewall_rules.main["vm-ci"]
  to   = module.zone_firewall.proxmox_virtual_environment_firewall_rules.main["vm-ci-01"]
}

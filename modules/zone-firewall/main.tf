# The zone firewall: one security group per zone holding its inbound rules from
# the transit matrix, and every VM's own firewall enabled with that group.
# Filtering happens on each guest's NIC; the node runs pve-firewall, whose
# VNet-level rules would need the nftables backend (a tech preview).

locals {
  groups = { for vnet, rules in var.rules : vnet => rules if length(rules) > 0 }
}

resource "proxmox_virtual_environment_cluster_firewall" "main" {
  enabled = var.enabled
}

# The host's own firewall stays off: its DROP policy would cut Traefik's 443.
# Node-bound rules and the DROP arrive with infrastructure#13.
resource "proxmox_node_firewall" "main" {
  node_name = var.node_name
  enabled   = false
}

resource "proxmox_virtual_environment_cluster_firewall_security_group" "main" {
  for_each = local.groups

  name    = "zone-${each.key}"
  comment = "Inbound rules for the ${each.key} zone, from docs/zones.md"

  dynamic "rule" {
    for_each = each.value
    content {
      type    = "in"
      action  = "ACCEPT"
      proto   = "tcp"
      source  = rule.value.source
      dport   = rule.value.dport
      comment = rule.value.comment
    }
  }
}

resource "proxmox_virtual_environment_firewall_options" "main" {
  for_each = var.vms

  node_name = var.node_name
  vm_id     = each.value.vm_id

  enabled       = true
  input_policy  = "DROP"
  output_policy = contains(var.no_egress, each.value.vnet) ? "DROP" : "ACCEPT"
  macfilter     = true
}

resource "proxmox_virtual_environment_firewall_rules" "main" {
  for_each = { for name, vm in var.vms : name => vm if contains(keys(local.groups), vm.vnet) }

  node_name = var.node_name
  vm_id     = each.value.vm_id

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.main[each.value.vnet].name
    comment        = "zone ${each.value.vnet}"
  }
}

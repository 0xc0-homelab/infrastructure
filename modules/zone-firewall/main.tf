# The zone firewall: one security group per zone holding its inbound rules from
# the transit matrix, and every VM's own firewall enabled with that group.
# Filtering happens on each guest's NIC; the node runs pve-firewall, whose
# VNet-level rules would need the nftables backend (a tech preview). The node
# itself gets its own rules and DROP policy.

locals {
  groups = { for vnet, rules in var.rules : vnet => rules if length(rules) > 0 }
}

resource "proxmox_virtual_environment_cluster_firewall" "main" {
  enabled = var.enabled
}

# Proxmox gives the network it detects as local implicit admin access to the
# node (22, 8006, 3128, 5900-5999, 60000-60050), outside any rule. Pointing
# local_network at loopback, which the node accepts anyway, leaves only the
# node rules below. An empty `management` ipset does not do it: the detected
# network is added regardless.
resource "proxmox_virtual_environment_firewall_alias" "local_network" {
  name    = "local_network"
  # A single address, as the API returns it: "/32" would diff on every plan.
  cidr    = "127.0.0.1"
  comment = "Overrides the detected network: no implicit admin access"
}

resource "proxmox_virtual_environment_firewall_rules" "node" {
  node_name = var.node_name

  dynamic "rule" {
    for_each = var.node_rules
    content {
      type    = "in"
      action  = "ACCEPT"
      proto   = "tcp"
      source  = rule.value.source == "" ? null : rule.value.source
      dport   = rule.value.dport
      comment = rule.value.comment
    }
  }
}

# The node's DROP policy. Turned on only once its rules exist: without them it
# cuts SSH over WARP and Traefik's 443.
resource "proxmox_node_firewall" "main" {
  node_name = var.node_name
  enabled   = var.node_enabled

  depends_on = [
    proxmox_virtual_environment_firewall_alias.local_network,
    proxmox_virtual_environment_firewall_rules.node,
  ]
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

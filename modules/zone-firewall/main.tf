# The zone firewall: one security group per zone holding its inbound rules from
# the transit matrix, and every VM's own firewall enabled with that group.
# Filtering happens on each guest's NIC; the node runs pve-firewall, whose
# VNet-level rules would need the nftables backend (a tech preview). The node
# itself gets its own rules and DROP policy.

# The transit matrix turned into rules. Each rule's comment is
# "<from> -> <to>: <note>", so every rule in Proxmox traces back to its line of
# terraform.tfvars.
locals {
  vnet_of = { for vnet, z in var.zones : z.alias => vnet }
  cidr_of = { for vnet, z in var.zones : z.alias => z.cidr }

  # Proxmox writes port ranges as a:b.
  dport = [for e in var.transit : join(",", [for p in e.ports : replace(p, "-", ":")])]

  # Inbound rules of each zone, in matrix order.
  rules = {
    for vnet, z in var.zones : vnet => [
      for i, e in var.transit : {
        source  = local.cidr_of[e.from]
        dport   = local.dport[i]
        comment = e.note == "" ? "${e.from} -> ${z.alias}" : "${e.from} -> ${z.alias}: ${e.note}"
      } if contains(e.to, z.alias)
    ]
  }
  groups = { for vnet, rules in local.rules : vnet => rules if length(rules) > 0 }

  # The node's rules. From an admin zone only the node's admin ports survive.
  node_ports = [
    for e in var.transit : (
      contains(var.node_admin.admin_zones, e.from)
      ? [for p in e.ports : p if contains(var.node_admin.admin_ports, p)]
      : e.ports
    )
  ]
  node_rules = [
    for i, e in var.transit : {
      source  = e.from == "internet" ? "" : local.cidr_of[e.from]
      dport   = join(",", [for p in local.node_ports[i] : replace(p, "-", ":")])
      comment = e.note == "" ? "${e.from} -> node" : "${e.from} -> node: ${e.note}"
    } if contains(e.to, "node") && length(local.node_ports[i]) > 0
  ]

  # Zones that initiate nothing (an entry with an empty `to`): their VMs get an
  # outbound DROP policy.
  no_egress = [for e in var.transit : local.vnet_of[e.from] if length(e.to) == 0 && contains(keys(local.vnet_of), e.from)]
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
  name = "local_network"
  # A single address, as the API returns it: "/32" would diff on every plan.
  cidr    = "127.0.0.1"
  comment = "Overrides the detected network: no implicit admin access"
}

resource "proxmox_virtual_environment_firewall_rules" "node" {
  node_name = var.node_name

  dynamic "rule" {
    for_each = local.node_rules
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
  comment = "Inbound rules for the ${each.key} zone, from the transit matrix"

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

# Proxmox deletes a VM's firewall config with the VM, and the provider cannot
# move rules to a new VMID in place. So a recreated VM, same VMID or not, gets
# its options and rules recreated: its MAC is new on every creation.
resource "terraform_data" "vm" {
  for_each = var.vms
  input    = each.value.mac
}

resource "proxmox_virtual_environment_firewall_options" "main" {
  for_each = var.vms

  node_name = var.node_name
  vm_id     = each.value.vm_id

  enabled       = true
  input_policy  = "DROP"
  output_policy = contains(local.no_egress, each.value.vnet) ? "DROP" : "ACCEPT"
  macfilter     = true

  lifecycle {
    replace_triggered_by = [terraform_data.vm[each.key]]
  }
}

resource "proxmox_virtual_environment_firewall_rules" "main" {
  for_each = { for name, vm in var.vms : name => vm if contains(keys(local.groups), vm.vnet) }

  node_name = var.node_name
  vm_id     = each.value.vm_id

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.main[each.value.vnet].name
    comment        = "zone ${each.value.vnet}"
  }

  lifecycle {
    replace_triggered_by = [terraform_data.vm[each.key]]
  }
}

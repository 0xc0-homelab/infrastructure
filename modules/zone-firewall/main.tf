locals {
  vnet_of = { for vnet, z in var.zones : z.alias => vnet }
  cidr_of = { for vnet, z in var.zones : z.alias => z.cidr }

  # Proxmox writes port ranges as a:b.
  dport = [for e in var.transit : join(",", [for p in e.ports : replace(p, "-", ":")])]

  source = [for e in var.transit : length(e.sources) > 0 ? join(",", e.sources) : lookup(local.cidr_of, e.from, "")]

  rules = {
    for vnet, z in var.zones : vnet => [
      for i, e in var.transit : {
        proto   = e.proto
        source  = local.source[i]
        dport   = local.dport[i]
        comment = e.note == "" ? "${e.from} -> ${z.alias}" : "${e.from} -> ${z.alias}: ${e.note}"
      } if contains(e.to, z.alias)
    ]
  }
  groups = { for vnet, rules in local.rules : vnet => rules if length(rules) > 0 }

  # From an admin zone only the node's admin ports survive.
  node_ports = [
    for e in var.transit : (
      contains(var.node_admin.admin_zones, e.from)
      ? [for p in e.ports : p if contains(var.node_admin.admin_ports, p)]
      : e.ports
    )
  ]
  node_rules = [
    for i, e in var.transit : {
      proto   = e.proto
      source  = local.source[i]
      dport   = join(",", [for p in local.node_ports[i] : replace(p, "-", ":")])
      comment = e.note == "" ? "${e.from} -> node" : "${e.from} -> node: ${e.note}"
    } if contains(e.to, "node") && length(local.node_ports[i]) > 0
  ]

  no_egress = [for e in var.transit : local.vnet_of[e.from] if length(e.to) == 0 && contains(keys(local.vnet_of), e.from)]
}

resource "proxmox_virtual_environment_cluster_firewall" "main" {
  enabled = var.enabled
}

# Proxmox grants the network it detects as local implicit admin access to the
# node, outside any rule. An empty `management` ipset does not stop it.
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
      proto   = rule.value.proto
      source  = rule.value.source == "" ? null : rule.value.source
      dport   = rule.value.dport
      comment = rule.value.comment
    }
  }
}

# Turned on only once its rules exist: without them it cuts SSH over WARP.
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
      type   = "in"
      action = "ACCEPT"
      proto  = rule.value.proto
      source = rule.value.source
      # A protocol without ports (vrrp) takes none.
      dport   = rule.value.dport == "" ? null : rule.value.dport
      comment = rule.value.comment
    }
  }
}

# Proxmox deletes a VM's firewall config with the VM: a recreated VM, whose
# MAC is new, gets its options and rules recreated.
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

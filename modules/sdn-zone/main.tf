# One Proxmox SDN Simple zone, with a VNet and a subnet per homelab zone. The
# host is the gateway (.1) of every subnet, and SNAT gives egress through the
# node's public interface where the zone is allowed out.

resource "proxmox_sdn_zone_simple" "main" {
  id    = var.zone_id
  nodes = var.nodes
  ipam  = "pve"

  depends_on = [proxmox_sdn_applier.finalizer]
}

resource "proxmox_sdn_vnet" "main" {
  for_each = var.vnets

  id    = each.key
  zone  = proxmox_sdn_zone_simple.main.id
  alias = each.value.alias

  depends_on = [proxmox_sdn_applier.finalizer]
}

resource "proxmox_sdn_subnet" "main" {
  for_each = var.vnets

  vnet    = proxmox_sdn_vnet.main[each.key].id
  cidr    = each.value.cidr
  gateway = cidrhost(each.value.cidr, 1)
  snat    = each.value.snat

  depends_on = [proxmox_sdn_applier.finalizer]
}

# SDN changes stay pending in Proxmox until applied. This applier is replaced —
# and so re-applies — whenever any zone, VNet or subnet changes.
resource "proxmox_sdn_applier" "changes" {
  lifecycle {
    replace_triggered_by = [
      proxmox_sdn_zone_simple.main,
      proxmox_sdn_vnet.main,
      proxmox_sdn_subnet.main,
    ]
  }

  depends_on = [
    proxmox_sdn_zone_simple.main,
    proxmox_sdn_vnet.main,
    proxmox_sdn_subnet.main,
  ]
}

# Everything above depends on this one, so on destroy it goes last and applies
# the removal.
resource "proxmox_sdn_applier" "finalizer" {}

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

# The whole set of VNets. A VNet removed from it is a destroy, which does not
# trigger a replace on its own; a change to this set does.
resource "terraform_data" "vnets" {
  input = var.vnets
}

# SDN changes stay pending until applied: replacing this re-applies them.
resource "proxmox_sdn_applier" "changes" {
  lifecycle {
    replace_triggered_by = [
      proxmox_sdn_zone_simple.main,
      proxmox_sdn_vnet.main,
      proxmox_sdn_subnet.main,
      terraform_data.vnets,
    ]
  }

  depends_on = [
    proxmox_sdn_zone_simple.main,
    proxmox_sdn_vnet.main,
    proxmox_sdn_subnet.main,
  ]
}

# On destroy it goes last and applies the removal.
resource "proxmox_sdn_applier" "finalizer" {}

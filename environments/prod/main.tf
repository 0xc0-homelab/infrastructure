# The prod environment of the node. This root only calls modules from
# ../../modules; resources live there.

module "sdn" {
  source = "../../modules/sdn-zone"

  zone_id = var.sdn_zone_id
  nodes   = var.nodes
  vnets   = var.zones
}

module "templates" {
  source   = "../../modules/cloud-image-template"
  for_each = var.templates

  name           = each.key
  vm_id          = each.value.vm_id
  node_name      = var.nodes[0]
  datastore_id   = var.template_datastore
  image_url      = each.value.image_url
  image_checksum = each.value.image_checksum
  bridge         = each.value.bridge

  # The default bridge is one of the SDN VNets.
  depends_on = [module.sdn]
}

module "zero_trust" {
  source = "../../modules/zero-trust"

  account_id       = var.cloudflare_account_id
  team_name        = var.zero_trust_team
  include_networks = [var.homelab_network]
  allowed_emails   = var.warp_allowed_emails
}

# The Default device profile exists as soon as Zero Trust is enabled: adopt it.
import {
  to = module.zero_trust.cloudflare_zero_trust_device_default_profile.main
  id = var.cloudflare_account_id
}

# vm-access's tunnel: the admin path. WARP clients reach every zone through it.
module "access_tunnel" {
  source = "../../modules/cloudflare-tunnel"

  account_id = var.cloudflare_account_id
  name       = "vm-access"
  routes     = [var.homelab_network]
}

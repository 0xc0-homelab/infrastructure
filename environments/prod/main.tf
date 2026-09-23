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

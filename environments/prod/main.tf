# The prod environment of the node. This root only calls modules from
# ../../modules; resources live there.

module "sdn" {
  source = "../../modules/sdn-zone"

  zone_id = var.sdn_zone_id
  nodes   = var.nodes
  vnets   = var.zones
}

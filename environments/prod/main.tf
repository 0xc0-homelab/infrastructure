# The prod environment of the node. This root only calls modules from
# ../../modules; resources live there.

module "sdn" {
  source = "../../modules/sdn-zone"

  zone_id = var.sdn_zone_id
  nodes   = var.nodes
  vnets   = var.zones
}

# Every template on the node, by name: the raw images imported here and the
# ones Packer bakes (packer/build-order). Packer rebuilds give a template a new
# VMID, so it is read from Proxmox, never written down.
data "proxmox_virtual_environment_vms" "templates" {
  node_name = var.nodes[0]

  filter {
    name   = "template"
    values = [true]
  }

  depends_on = [module.templates]
}

locals {
  template_ids = { for vm in data.proxmox_virtual_environment_vms.templates.vms : vm.name => vm.vm_id }
}

module "templates" {
  source   = "../../modules/cloud-image-template"
  for_each = var.templates

  name           = each.key
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

  private_hostnames    = var.node_web_hostnames
  private_hostnames_ip = cidrhost(var.zones["mgmt"].cidr, 1)
}

# vm-access's tunnel: the admin path. WARP clients reach every zone through it.
module "access_tunnel" {
  source = "../../modules/cloudflare-tunnel"

  account_id = var.cloudflare_account_id
  name       = "vm-access"
  routes     = [var.homelab_network]
}

module "vms" {
  source   = "../../modules/vm"
  for_each = var.vms

  name           = each.key
  rebuild        = each.value.rebuild
  node_name      = var.nodes[0]
  template_vm_id = local.template_ids[each.value.template]
  datastore_id   = var.template_datastore

  vnet         = each.value.vnet
  ipv4_address = "${each.value.ip}/${split("/", var.zones[each.value.vnet].cidr)[1]}"
  ipv4_gateway = cidrhost(var.zones[each.value.vnet].cidr, 1)
  dns_servers  = var.vm_dns_servers

  cores        = each.value.cores
  memory_mb    = each.value.memory_mb
  disk_size_gb = each.value.disk_size_gb

  username        = var.vm_admin_user
  ssh_public_keys = var.vm_admin_ssh_keys
  tags            = [each.value.vnet]

  # The VNets must exist before a VM can attach to one.
  depends_on = [module.sdn]
}

# The zone firewall: the rules of every zone and of the node, computed from the
# transit matrix in terraform.tfvars.
module "zone_firewall" {
  source = "../../modules/zone-firewall"

  node_name    = var.nodes[0]
  enabled      = var.datacenter_firewall_enabled
  node_enabled = var.node_firewall_enabled
  zones        = { for vnet, z in var.zones : vnet => { alias = z.alias, cidr = z.cidr } }
  transit      = var.transit
  node_admin   = var.node_firewall
  vms = { for name, vm in var.vms : name => {
    vm_id = module.vms[name].vm_id
    vnet  = vm.vnet
    mac   = module.vms[name].mac_address
  } }

  depends_on = [module.vms]
}

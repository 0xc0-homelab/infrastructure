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
  vm_id          = each.value.vm_id
  node_name      = var.nodes[0]
  datastore_id   = var.template_datastore
  image_url      = each.value.image_url
  image_checksum = each.value.image_checksum

  image_checksum_algorithm = each.value.checksum_algorithm
  disk_size_gb             = each.value.disk_size_gb
  bridge                   = each.value.bridge

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

  # The WARP-only path (gitops: Traefik's internal entrypoint).
  internal_domains = var.internal_domains
  internal_ip      = var.cluster.internal_vip
}

# Mail to the operator's domains, forwarded to their mailboxes (#157, #160),
# once per domain: each may be in another Cloudflare account. Nothing receives
# or sends mail here.
module "email_routing" {
  source = "../../modules/email-routing"
  # The domains are not secret; their addresses and destinations are.
  for_each = toset(nonsensitive(keys(var.email_forwards)))

  zone_name    = each.key
  destinations = var.email_destinations
  forwards     = var.email_forwards[each.key].addresses
  catch_all    = var.email_forwards[each.key].catch_all
}

# 0xc0.cc's, from before the module was called per domain.
moved {
  from = module.email_routing
  to   = module.email_routing["0xc0.cc"]
}

# The public tunnel: its connectors run on the load balancers, and it goes to
# HAProxy on the VIP, then Traefik over HTTPS. Public traffic enters platform,
# never mgmt. Every name of a public domain goes to Traefik, which routes it or
# answers 404; a name is public only once external-dns (gitops) gives it a
# record. The portals stay on WARP, with no record.
module "public_tunnel" {
  source = "../../modules/cloudflare-tunnel"

  account_id = var.cloudflare_account_id
  name       = "public"
  ingress = flatten([for d in var.public_domains : [
    for h in ["*.${d}", d] : { hostname = h, service = "https://${var.cluster.vip}:443" }
  ]])
}

# The admin tunnel: the admin path. WARP clients reach every zone through it;
# its connectors run on vm-access-01 and vm-access-02.
module "admin_tunnel" {
  source = "../../modules/cloudflare-tunnel"

  account_id = var.cloudflare_account_id
  name       = "admin"
  routes     = [var.homelab_network]
}

module "vms" {
  source   = "../../modules/vm"
  for_each = var.vms

  name      = each.key
  rebuild   = each.value.rebuild
  cpu_type  = each.value.cpu_type
  node_name = var.nodes[0]
  # A template is missing for a while when Packer rebuilds it (it deletes it
  # first). Existing VMs ignore their template, so their plan must not fail
  # then. The fallback is the highest valid VMID, which never exists: a new VM
  # created in that window fails to find its template instead of cloning
  # another one.
  template_vm_id = lookup(local.template_ids, each.value.template, 2147483647)
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

# The RKE2 cluster (servers and agents) and its HAProxy + keepalived pair,
# created together.
module "cluster" {
  source = "../../modules/rke2-cluster"

  node_name    = var.nodes[0]
  datastore_id = var.template_datastore
  vnet         = var.cluster.vnet
  cidr         = var.zones[var.cluster.vnet].cidr
  dns_servers  = var.vm_dns_servers

  # The same fallback as the vms: a missing template must not fail the plan.
  load_balancers = {
    template_vm_id = lookup(local.template_ids, var.cluster.load_balancers.template, 2147483647)
    cores          = var.cluster.load_balancers.cores
    memory_mb      = var.cluster.load_balancers.memory_mb
    disk_size_gb   = var.cluster.load_balancers.disk_size_gb
    nodes          = var.cluster.load_balancers.nodes
  }
  servers = {
    template_vm_id = lookup(local.template_ids, var.cluster.servers.template, 2147483647)
    cpu_type       = var.cluster.servers.cpu_type
    cores          = var.cluster.servers.cores
    memory_mb      = var.cluster.servers.memory_mb
    disk_size_gb   = var.cluster.servers.disk_size_gb
    data_disks_gb  = var.cluster.servers.data_disks_gb
    nodes          = var.cluster.servers.nodes
  }
  agents = {
    template_vm_id = lookup(local.template_ids, var.cluster.agents.template, 2147483647)
    cpu_type       = var.cluster.agents.cpu_type
    cores          = var.cluster.agents.cores
    memory_mb      = var.cluster.agents.memory_mb
    disk_size_gb   = var.cluster.agents.disk_size_gb
    data_disks_gb  = var.cluster.agents.data_disks_gb
    nodes          = var.cluster.agents.nodes
  }

  username        = var.vm_admin_user
  ssh_public_keys = var.vm_admin_ssh_keys

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
  # Sources are VM names in tfvars; the module takes their addresses.
  transit = [for e in var.transit : merge(e, {
    sources = [for s in e.sources : var.vms[s].ip]
  })]
  node_admin = var.node_firewall
  vms = merge(
    { for name, vm in var.vms : name => {
      vm_id = module.vms[name].vm_id
      vnet  = vm.vnet
      mac   = module.vms[name].mac_address
    } },
    module.cluster.vms,
  )

  depends_on = [module.vms, module.cluster]
}

# Every VM to PBS, daily, data disks included: that covers the Longhorn volumes
# on the RKE2 servers. Templates stay out; Packer rebuilds them.
module "backup" {
  source = "../../modules/backup-job"

  id        = "vms-daily"
  node_name = var.nodes[0]
  storage   = var.backup.storage
  schedule  = var.backup.schedule
  vm_ids = concat(
    [for name, vm in module.vms : vm.vm_id],
    [for name, vm in module.cluster.vms : vm.vm_id],
  )
  retention = var.backup.retention
}

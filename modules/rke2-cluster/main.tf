# The RKE2 cluster and its load balancer, deployed together: the servers and
# the HAProxy + keepalived pair in front of them, all in one zone. The VIP is
# keepalived's, set up by Ansible; no VM holds it here. Everything inside the
# guests is Ansible's job (playbooks/cluster.yml).

locals {
  prefix_length = split("/", var.cidr)[1]
  gateway       = cidrhost(var.cidr, 1)
}

module "load_balancers" {
  source   = "../vm"
  for_each = var.load_balancers.nodes

  name           = each.key
  rebuild        = each.value.rebuild
  node_name      = var.node_name
  template_vm_id = var.load_balancers.template_vm_id
  datastore_id   = var.datastore_id

  vnet         = var.vnet
  ipv4_address = "${each.value.ip}/${local.prefix_length}"
  ipv4_gateway = local.gateway
  dns_servers  = var.dns_servers

  cores        = var.load_balancers.cores
  memory_mb    = var.load_balancers.memory_mb
  disk_size_gb = var.load_balancers.disk_size_gb

  username        = var.username
  ssh_public_keys = var.ssh_public_keys
  tags            = [var.vnet, "lb"]
}

module "servers" {
  source   = "../vm"
  for_each = var.servers.nodes

  name           = each.key
  rebuild        = each.value.rebuild
  node_name      = var.node_name
  template_vm_id = var.servers.template_vm_id
  datastore_id   = var.datastore_id
  cpu_type       = var.servers.cpu_type

  vnet         = var.vnet
  ipv4_address = "${each.value.ip}/${local.prefix_length}"
  ipv4_gateway = local.gateway
  dns_servers  = var.dns_servers

  cores         = var.servers.cores
  memory_mb     = var.servers.memory_mb
  disk_size_gb  = var.servers.disk_size_gb
  data_disks_gb = var.servers.data_disks_gb

  username        = var.username
  ssh_public_keys = var.ssh_public_keys
  tags            = [var.vnet, "rke2"]
}

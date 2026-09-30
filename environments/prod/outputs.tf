output "cluster" {
  description = "The cluster's VIP and the addresses of its load balancers and servers, for the Ansible inventory and kubectl."
  value = {
    vip            = var.cluster.vip
    load_balancers = module.cluster.load_balancers
    servers        = module.cluster.servers
  }
}

output "vm_admin_ssh_keys" {
  description = "The public keys every VM's admin user accepts. cloud-init sets them on a new VM; Ansible's base role reads them here to keep them on every VM."
  value       = var.vm_admin_ssh_keys
}

output "public_tunnel_token" {
  description = "Connector token for cloudflared on the load balancers. Read it with tofu output -raw, straight into Ansible; never to a file."
  value       = module.public_tunnel.token
  sensitive   = true
}

output "admin_tunnel_token" {
  description = "Connector token for cloudflared on vm-access-01 and vm-access-02. Read it with tofu output -raw, straight into Ansible; never to a file."
  value       = module.admin_tunnel.token
  sensitive   = true
}

output "public_tunnel_id" {
  description = "The public tunnel's ID: external-dns (gitops, platform/traefik) points public names at <id>.cfargotunnel.com."
  value       = module.public_tunnel.id
}

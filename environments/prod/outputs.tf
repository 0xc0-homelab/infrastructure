output "cluster" {
  description = "The cluster's VIP and the addresses of its load balancers and servers, for the Ansible inventory and kubectl."
  value = {
    vip            = var.cluster.vip
    load_balancers = module.cluster.load_balancers
    servers        = module.cluster.servers
  }
}

output "vm_access_tunnel_token" {
  description = "Connector token for cloudflared on vm-access. Read it with tofu output -raw, straight into Ansible; never to a file."
  value       = module.access_tunnel.token
  sensitive   = true
}

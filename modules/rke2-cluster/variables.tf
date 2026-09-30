variable "node_name" {
  description = "Proxmox node."
  type        = string
}

variable "datastore_id" {
  description = "Datastore for the disks and the cloud-init drives."
  type        = string
}

variable "vnet" {
  description = "SDN VNet the whole cluster attaches to — its zone."
  type        = string
}

variable "cidr" {
  description = "The zone's CIDR: every address is inside it, and the host's .1 is the gateway."
  type        = string
}

variable "dns_servers" {
  description = "Resolvers written by cloud-init."
  type        = list(string)
}

variable "username" {
  description = "Admin user created by cloud-init; SSH keys only, no password."
  type        = string
}

variable "ssh_public_keys" {
  description = "Public keys authorised for username."
  type        = list(string)
}

variable "load_balancers" {
  description = "The HAProxy + keepalived pair: the template to clone, the size, and each VM's address."
  type = object({
    template_vm_id = number
    cores          = number
    memory_mb      = number
    disk_size_gb   = number
    nodes = map(object({
      ip      = string
      rebuild = number
    }))
  })

  validation {
    condition     = length(var.load_balancers.nodes) == 2
    error_message = "keepalived runs as a pair: exactly two load balancers."
  }
}

variable "servers" {
  description = "The RKE2 servers — control plane, etcd and workloads together: the template, the size, the data disks, and each VM's address."
  type = object({
    template_vm_id = number
    cpu_type       = string
    cores          = number
    memory_mb      = number
    disk_size_gb   = number
    data_disks_gb  = list(number)
    nodes = map(object({
      ip      = string
      rebuild = number
    }))
  })

  validation {
    condition     = contains([1, 3, 5], length(var.servers.nodes))
    error_message = "etcd needs an odd number of servers: 1, 3 or 5."
  }
}

variable "agents" {
  description = "The RKE2 agents — workloads only, no control plane or etcd: the template, the size, the data disks, and each VM's address. An empty nodes map for none."
  type = object({
    template_vm_id = number
    cpu_type       = string
    cores          = number
    memory_mb      = number
    disk_size_gb   = number
    data_disks_gb  = list(number)
    nodes = map(object({
      ip      = string
      rebuild = number
    }))
  })
}

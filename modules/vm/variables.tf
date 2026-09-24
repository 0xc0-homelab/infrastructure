variable "name" {
  description = "VM name, e.g. vm-access-01."
  type        = string
}

variable "rebuild" {
  description = "Bump to recreate the VM, keeping everything else as it is."
  type        = number
  default     = 0
}

variable "node_name" {
  description = "Proxmox node."
  type        = string
}

variable "template_vm_id" {
  description = "VMID of the template to clone."
  type        = number
}

variable "datastore_id" {
  description = "Datastore for the disk and the cloud-init drive."
  type        = string
}

variable "vnet" {
  description = "SDN VNet the VM attaches to — its zone."
  type        = string
}

variable "ipv4_address" {
  description = "Static address in CIDR notation, inside the zone, e.g. 10.10.0.10/24."
  type        = string
}

variable "ipv4_gateway" {
  description = "Gateway: the host, on the zone's .1."
  type        = string
}

variable "dns_servers" {
  description = "Resolvers written by cloud-init."
  type        = list(string)
}

variable "cores" {
  description = "vCPUs."
  type        = number
  default     = 1
}

variable "memory_mb" {
  description = "Memory in MB."
  type        = number
  default     = 1024
}

variable "disk_size_gb" {
  description = "Root disk size. It can grow from the template's, never shrink."
  type        = number
  default     = 8
}

variable "username" {
  description = "Admin user created by cloud-init; SSH keys only, no password."
  type        = string
}

variable "ssh_public_keys" {
  description = "Public keys authorised for username."
  type        = list(string)
}

variable "tags" {
  description = "Proxmox tags."
  type        = list(string)
  default     = []
}

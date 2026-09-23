variable "node_name" {
  description = "Proxmox node."
  type        = string
}

variable "enabled" {
  description = "The datacenter firewall's master switch. Nothing below is enforced while it is false."
  type        = bool
}

variable "rules" {
  description = "Inbound rules per zone, keyed by VNet — generated from docs/zones.md into firewall.tf."
  type = map(list(object({
    source  = string
    dport   = string
    comment = string
  })))
}

variable "no_egress" {
  description = "VNets whose VMs initiate nothing: outbound policy DROP."
  type        = list(string)
}

variable "vms" {
  description = "Every VM, with its VMID and VNet."
  type = map(object({
    vm_id = number
    vnet  = string
  }))
}

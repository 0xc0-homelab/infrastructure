variable "node_name" {
  description = "Proxmox node."
  type        = string
}

variable "enabled" {
  description = "The datacenter firewall's master switch. Nothing below is enforced while it is false."
  type        = bool
}

variable "zones" {
  description = "Every zone, keyed by VNet ID: its alias (the name the transit matrix uses) and CIDR."
  type = map(object({
    alias = string
    cidr  = string
  }))
}

variable "transit" {
  description = "The transit matrix, validated by the root. Each entry becomes rules commented \"<from> -> <to>: <note>\"."
  type = list(object({
    from  = string
    to    = list(string)
    ports = list(string)
    note  = string
  }))
}

variable "node_admin" {
  description = "From admin_zones the node admits only admin_ports; from anywhere else, an entry's ports as written."
  type = object({
    admin_zones = list(string)
    admin_ports = list(string)
  })
}

variable "node_enabled" {
  description = "The node's own firewall: DROP on everything but its rules. Needs `enabled` too."
  type        = bool
}

variable "vms" {
  description = "Every VM, with its VMID, VNet and NIC MAC. A new MAC means the VM was recreated."
  type = map(object({
    vm_id = number
    vnet  = string
    mac   = string
  }))
}

variable "zone_id" {
  description = "SDN zone ID. Proxmox allows letters and digits only, up to 8 characters."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9]{0,6}[a-zA-Z0-9]$", var.zone_id))
    error_message = "zone_id: letters and digits, starting with a letter, 2 to 8 characters."
  }
}

variable "nodes" {
  description = "Proxmox nodes the zone and its VNets are deployed on."
  type        = list(string)
}

variable "vnets" {
  description = "One VNet per homelab zone, keyed by VNet ID (letters and digits, up to 8 characters). The gateway is always the host, on the first address of the CIDR."
  type = map(object({
    alias = string
    cidr  = string
    snat  = bool
  }))

  validation {
    condition     = alltrue([for id in keys(var.vnets) : can(regex("^[a-zA-Z][a-zA-Z0-9]{0,6}[a-zA-Z0-9]$", id))])
    error_message = "VNet IDs: letters and digits, starting with a letter, 2 to 8 characters. Put the full name in alias."
  }

  validation {
    condition     = alltrue([for v in values(var.vnets) : can(cidrhost(v.cidr, 1))])
    error_message = "Every cidr must be a valid IPv4 CIDR with room for a gateway."
  }
}

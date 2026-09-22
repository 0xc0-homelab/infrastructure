variable "nodes" {
  description = "Proxmox nodes in the cluster."
  type        = list(string)
}

variable "sdn_zone_id" {
  description = "ID of the SDN Simple zone holding every homelab zone."
  type        = string
}

variable "zones" {
  description = "The homelab zones, keyed by VNet ID. Must match docs/zones.md, which is normative."
  type = map(object({
    alias = string
    cidr  = string
    snat  = bool
  }))

  # Every zone lives in 10.10.0.0/16, so none can land on a reserved range
  # (10.11/16, 10.20/16, 10.42/16, 10.43/16, 10.66.66/24).
  validation {
    condition = alltrue([
      for z in values(var.zones) :
      startswith(cidrhost(z.cidr, 0), "10.10.") && tonumber(split("/", z.cidr)[1]) >= 16
    ])
    error_message = "Every zone CIDR must sit inside 10.10.0.0/16. The reserved ranges are listed in docs/zones.md."
  }

  # data initiates nothing (t10): it must never get SNAT.
  validation {
    condition     = alltrue([for id, z in var.zones : !(z.alias == "data" && z.snat)])
    error_message = "The data zone must not have SNAT: it initiates no connection (t10 in docs/zones.md)."
  }
}

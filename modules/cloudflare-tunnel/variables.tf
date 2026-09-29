variable "account_id" {
  description = "Cloudflare account ID."
  type        = string
}

variable "name" {
  description = "Tunnel name, usually the VM that runs its connector."
  type        = string
}

variable "routes" {
  description = "Private networks, in CIDR notation, routed through this tunnel for WARP clients."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for r in var.routes : can(cidrhost(r, 0))])
    error_message = "Every route must be a valid CIDR."
  }
}

variable "ingress" {
  description = "Public hostnames the tunnel serves, each with the origin it goes to (e.g. http://10.10.4.10:80), before a catch-all 404. null for a tunnel with no public side; [] for one that exposes nothing yet."
  type = list(object({
    hostname = string
    service  = string
  }))
  default = null
}

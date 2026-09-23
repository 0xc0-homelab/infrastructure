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

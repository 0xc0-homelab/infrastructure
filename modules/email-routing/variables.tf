variable "account_id" {
  description = "Cloudflare account holding the zone; destination addresses are account-wide."
  type        = string
}

variable "zone_name" {
  description = "Zone that receives the mail, e.g. 0xc0.cc."
  type        = string
}

variable "destinations" {
  description = "Mailboxes mail is forwarded to, by a name of the caller's choosing. Each must be verified once, from Cloudflare's confirmation mail, before forwarding to it works."
  type        = map(string)
  sensitive   = true
}

variable "forwards" {
  description = "Address in the zone => name of the destination it forwards to (a key of destinations)."
  type        = map(string)

  validation {
    condition     = alltrue([for from in keys(var.forwards) : can(regex("^[^@]+@[^@]+$", from))])
    error_message = "Every forwarded address must be a full address, local@domain."
  }
}

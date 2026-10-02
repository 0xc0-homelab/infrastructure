variable "zone_name" {
  description = "Zone that receives the mail, e.g. 0xc0.cc. Its account, found from it, holds the destination addresses."
  type        = string
}

variable "destinations" {
  description = "Mailboxes mail is forwarded to, by a name of the caller's choosing. Each must be verified once per account, from Cloudflare's confirmation mail, before forwarding to it works."
  type        = map(string)
  sensitive   = true
}

variable "forwards" {
  description = "Address in the zone => name of the destination it forwards to (a key of destinations). Sensitive: the addresses never show in a plan."
  type        = map(string)
  sensitive   = true

  validation {
    condition     = alltrue([for from in keys(var.forwards) : endswith(from, "@${var.zone_name}") && can(regex("^[^@]+@[^@]+$", from))])
    error_message = "Every forwarded address must be a full address in the zone, local@<zone_name>."
  }
}

variable "catch_all" {
  description = "Name of the destination mail to any other address of the zone goes to (a key of destinations). null leaves the zone's catch-all as Cloudflare has it, unmanaged."
  type        = string
  default     = null
  sensitive   = true
}

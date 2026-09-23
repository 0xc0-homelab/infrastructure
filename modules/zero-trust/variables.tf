variable "account_id" {
  description = "Cloudflare account ID."
  type        = string
}

variable "team_name" {
  description = "Zero Trust team name. Also the team domain: <team_name>.cloudflareaccess.com."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.team_name))
    error_message = "team_name: lowercase letters, digits and hyphens."
  }
}

variable "include_networks" {
  description = "The only networks WARP carries (split tunnels in Include mode). Everything else stays off the tunnel."
  type        = list(string)

  validation {
    condition     = length(var.include_networks) > 0 && alltrue([for n in var.include_networks : can(cidrhost(n, 0))])
    error_message = "include_networks: at least one valid CIDR."
  }
}

variable "allowed_emails" {
  description = "Who may enroll a device into the organization's WARP — and so reach the private networks."
  type        = list(string)
  sensitive   = true
}

variable "tunnel_protocol" {
  description = "WARP tunnel protocol. MASQUE is the account's current setting."
  type        = string
  default     = "masque"

  validation {
    condition     = contains(["masque", "wireguard"], var.tunnel_protocol)
    error_message = "tunnel_protocol must be masque or wireguard."
  }
}

variable "private_hostnames" {
  description = "Hostnames that WARP devices resolve to private_hostnames_ip instead of their public record."
  type        = list(string)
}

variable "private_hostnames_ip" {
  description = "Private address those hostnames resolve to for WARP devices, inside include_networks."
  type        = string
}

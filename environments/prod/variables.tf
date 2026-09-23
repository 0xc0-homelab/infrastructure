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

variable "template_datastore" {
  description = "Datastore holding cloud images and VM templates. Must allow the import content type."
  type        = string
}

variable "templates" {
  description = "VM templates built from official cloud images, keyed by template name."
  type = map(object({
    vm_id          = number
    image_url      = string
    image_checksum = string
    bridge         = string
  }))
}

variable "cloudflare_account_id" {
  description = "Cloudflare account holding the tunnels and Zero Trust."
  type        = string
}

variable "zero_trust_team" {
  description = "Zero Trust team name; the team domain is <team>.cloudflareaccess.com."
  type        = string
}

variable "homelab_network" {
  description = "Every homelab zone, as one CIDR: what WARP carries, and what vm-access routes."
  type        = string

  validation {
    condition     = var.homelab_network == "10.10.0.0/16"
    error_message = "homelab_network must be 10.10.0.0/16, the supernet of every zone in docs/zones.md."
  }
}

# Not a secret, but kept out of this public repo: it comes from
# secrets/tofu.sops.yaml as TF_VAR_warp_allowed_emails.
variable "warp_allowed_emails" {
  description = "Who may enroll a WARP device, and so reach the homelab."
  type        = list(string)
  sensitive   = true
}

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

variable "vm_admin_user" {
  description = "Admin user cloud-init creates on every VM. SSH keys only."
  type        = string
}

variable "vm_admin_ssh_keys" {
  description = "Public SSH keys authorised on every VM."
  type        = list(string)
}

variable "vm_dns_servers" {
  description = "Resolvers for every VM."
  type        = list(string)
}

variable "vms" {
  description = "VMs, keyed by name. Must match the vms block of docs/zones.md, which is normative."
  type = map(object({
    vm_id        = number
    template     = string
    vnet         = string
    ip           = string
    cores        = optional(number, 1)
    memory_mb    = optional(number, 1024)
    disk_size_gb = optional(number, 8)
  }))

  # The address must sit inside its zone, and never on the host's .1.
  validation {
    condition = alltrue([
      for v in values(var.vms) :
      contains(keys(var.zones), v.vnet)
      && cidrhost("${v.ip}/${split("/", var.zones[v.vnet].cidr)[1]}", 0) == cidrhost(var.zones[v.vnet].cidr, 0)
      && v.ip != cidrhost(var.zones[v.vnet].cidr, 1)
    ])
    error_message = "Every VM's ip must be inside its vnet's zone and must not be the host's .1 — see docs/zones.md."
  }

  validation {
    condition     = length(distinct([for v in values(var.vms) : v.ip])) == length(var.vms)
    error_message = "Two VMs share an address."
  }
}

variable "node_firewall_enabled" {
  description = "The node's own firewall and its DROP policy. Only 22 and 8006 from control, and what docs/zones.md sends to the node."
  type        = bool
}

variable "datacenter_firewall_enabled" {
  description = "Proxmox datacenter firewall master switch. While off, no VM firewall is enforced."
  type        = bool
}

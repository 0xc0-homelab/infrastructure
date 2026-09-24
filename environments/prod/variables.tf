variable "nodes" {
  description = "Proxmox nodes in the cluster."
  type        = list(string)
}

variable "sdn_zone_id" {
  description = "ID of the SDN Simple zone holding every homelab zone."
  type        = string
}

variable "zones" {
  description = "The homelab zones, keyed by VNet ID. docs/zones.md explains them."
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

  # data initiates nothing: it must never get SNAT.
  validation {
    condition     = alltrue([for id, z in var.zones : !(z.alias == "data" && z.snat)])
    error_message = "The data zone must not have SNAT: it initiates no connection."
  }
}

variable "template_datastore" {
  description = "Datastore holding cloud images and VM templates. Must allow the import content type."
  type        = string
}

variable "templates" {
  description = "Official cloud images, imported as raw templates and keyed by template name. Packer bakes the templates VMs use from them."
  type = map(object({
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
    error_message = "homelab_network must be 10.10.0.0/16, the supernet of every zone."
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
  description = "The VMs, keyed by name. Their addresses follow the plan in docs/zones.md."
  type = map(object({
    template     = string
    vnet         = string
    ip           = string
    cores        = optional(number, 1)
    memory_mb    = optional(number, 1024)
    disk_size_gb = optional(number, 8)
    # Bump to recreate the VM from its template.
    rebuild = optional(number, 0)
    # The QEMU guest agent. False only until the VM is rebuilt from a baked
    # template: switching it on in place reboots the VM.
    guest_agent = optional(bool, true)
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
  description = "The node's own firewall and its DROP policy: it admits only what the transit matrix sends to the node."
  type        = bool
}

variable "datacenter_firewall_enabled" {
  description = "Proxmox datacenter firewall master switch. While off, no VM firewall is enforced."
  type        = bool
}

variable "node_web_hostnames" {
  description = "Hostnames Traefik serves on the node. WARP devices resolve them to the node's address in mgmt."
  type        = list(string)
}

variable "transit" {
  description = "The transit matrix: every flow the firewall allows, all TCP. from/to are zone aliases, node or internet; an empty to means the zone initiates nothing."
  type = list(object({
    from  = string
    to    = list(string)
    ports = list(string)
    note  = optional(string, "")
  }))

  validation {
    condition     = alltrue([for e in var.transit : can(regex("^[ -~]*$", e.note))])
    error_message = "Transit notes must be plain ASCII: they become Proxmox rule comments."
  }

  # Invariant: data initiates nothing.
  validation {
    condition     = alltrue([for e in var.transit : !(e.from == "data" && length(e.to) > 0)])
    error_message = "data initiates nothing: no transit entry from data may have a destination."
  }

  # Invariant: nobody initiates towards mgmt, except from inside mgmt.
  validation {
    condition     = alltrue([for e in var.transit : !(contains(e.to, "mgmt") && e.from != "mgmt")])
    error_message = "Nothing may initiate towards mgmt from another zone."
  }

  # Invariant: the node accepts nothing from the internet.
  validation {
    condition     = alltrue([for e in var.transit : !(e.from == "internet" && contains(e.to, "node"))])
    error_message = "The node accepts nothing from the internet: Traefik is reached over WARP."
  }
}

variable "node_firewall" {
  description = "The node's DROP: from admin_zones it admits only admin_ports, whatever else an entry opens; from anywhere else, an entry's ports as written."
  type = object({
    admin_zones = list(string)
    admin_ports = list(string)
  })
}

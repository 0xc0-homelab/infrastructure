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
    # 9000-9099: the raw images. Packer's templates take 9100-9199.
    vm_id              = number
    image_url          = string
    image_checksum     = string
    checksum_algorithm = optional(string, "sha512")
    # At least the image's virtual size: Proxmox never shrinks a disk.
    disk_size_gb = optional(number, 8)
    bridge       = string
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
# Vault (ci/infrastructure/warp) as TF_VAR_warp_allowed_emails.
variable "warp_allowed_emails" {
  description = "Who may enroll a WARP device, and so reach the homelab."
  type        = list(string)
  sensitive   = true
}

# Not a secret, but kept out of this public repo: the operator's mailboxes, as
# JSON ({"operator": "..."}), from Vault (ci/infrastructure/email-routing) as
# TF_VAR_email_destinations.
variable "email_destinations" {
  description = "Mailboxes Email Routing forwards to, by name."
  type        = map(string)
  sensitive   = true
}

variable "email_forwards" {
  description = "Email Routing, by domain: address => the name of its destination in email_destinations."
  type        = map(map(string))
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
    # The QEMU CPU model. Rocky 10 needs x86-64-v3.
    cpu_type = optional(string, "x86-64-v2-AES")
    # Bump to recreate the VM from its template. prevent_destroy, in the vm
    # module, has to be lifted in the same PR.
    rebuild = optional(number, 0)
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
  description = "The transit matrix: every flow the firewall allows. from/to are zone aliases, node or internet; an empty to means the zone initiates nothing. proto is tcp unless stated."
  type = list(object({
    from  = string
    to    = list(string)
    proto = optional(string, "tcp")
    ports = list(string)
    # VM names in the from zone: the entry then admits only their addresses,
    # not the whole zone.
    sources = optional(list(string), [])
    note    = optional(string, "")
  }))

  # TCP and UDP entries name their ports; a protocol without ports (vrrp) names
  # none.
  validation {
    condition = alltrue([
      for e in var.transit :
      contains(["tcp", "udp", "vrrp"], e.proto)
      && (contains(["tcp", "udp"], e.proto) ? (length(e.ports) > 0 || length(e.to) == 0) : length(e.ports) == 0)
    ])
    error_message = "Every transit entry is tcp, udp or vrrp; tcp and udp entries list their ports, vrrp entries list none."
  }

  validation {
    condition     = alltrue([for e in var.transit : can(regex("^[ -~]*$", e.note))])
    error_message = "Transit notes must be plain ASCII: they become Proxmox rule comments."
  }

  # Invariant: data initiates nothing.
  validation {
    condition     = alltrue([for e in var.transit : !(e.from == "data" && length(e.to) > 0)])
    error_message = "data initiates nothing: no transit entry from data may have a destination."
  }

  # Invariant: nobody initiates towards mgmt, except from inside mgmt and one
  # exception: SSH from named CI VMs, for the pipeline's playbooks (operator
  # decision, 2026-09-29).
  validation {
    condition = alltrue([
      for e in var.transit :
      !(contains(e.to, "mgmt") && e.from != "mgmt")
      || (e.from == "ci" && length(e.sources) > 0 && e.proto == "tcp" && length(e.ports) == 1 && tostring(e.ports[0]) == "22")
    ])
    error_message = "Nothing may initiate towards mgmt from another zone, except SSH (22) from named CI VMs (sources)."
  }

  # A source is a VM of the entry's own from zone.
  validation {
    condition = alltrue(flatten([
      for e in var.transit : [for s in e.sources : contains(keys(var.vms), s) && try(var.vms[s].vnet, "") == e.from]
    ]))
    error_message = "Every transit source must be a VM in the vms map, in the entry's from zone."
  }

  # Invariant: from the internet the node accepts only break-glass SSH, which
  # the Hetzner firewall keeps closed until the operator opens it.
  validation {
    condition     = alltrue([for e in var.transit : !(e.from == "internet" && contains(e.to, "node")) || (length(e.ports) == 1 && e.ports[0] == "22")])
    error_message = "From the internet the node accepts only SSH (22), as break-glass: Traefik and the API are reached over WARP."
  }
}

variable "node_firewall" {
  description = "The node's DROP: from admin_zones it admits only admin_ports, whatever else an entry opens; from anywhere else, an entry's ports as written."
  type = object({
    admin_zones = list(string)
    admin_ports = list(string)
  })
}

variable "cluster" {
  description = "The RKE2 cluster and its load balancer pair, in one zone. The VIP is keepalived's, in front of HAProxy; addresses follow the plan in docs/zones.md."
  type = object({
    vnet = string
    vip  = string
    # The WARP-only path's VIP, on the same load balancers: *.int.0xc0.cc.
    internal_vip = string
    load_balancers = object({
      template     = string
      cores        = optional(number, 1)
      memory_mb    = optional(number, 1024)
      disk_size_gb = optional(number, 10)
      nodes = map(object({
        ip = string
        # Bump to recreate the VM, as in vms.
        rebuild = optional(number, 0)
      }))
    })
    servers = object({
      template = string
      # RKE2 on Rocky 10, which needs x86-64-v3.
      cpu_type     = optional(string, "x86-64-v3")
      cores        = optional(number, 4)
      memory_mb    = optional(number, 12288)
      disk_size_gb = optional(number, 100)
      # Blank disks on top of the root one, scsi1 onwards.
      data_disks_gb = optional(list(number), [])
      nodes = map(object({
        ip      = string
        rebuild = optional(number, 0)
      }))
    })
    # Workers only, sized like the servers unless told otherwise.
    agents = optional(object({
      template      = optional(string, "rocky-10-base")
      cpu_type      = optional(string, "x86-64-v3")
      cores         = optional(number, 4)
      memory_mb     = optional(number, 12288)
      disk_size_gb  = optional(number, 100)
      data_disks_gb = optional(list(number), [])
      nodes = optional(map(object({
        ip      = string
        rebuild = optional(number, 0)
      })), {})
    }), {})
  })

  # The VIP and every address sit inside the zone, never on the host's .1, and
  # no machine takes the VIP.
  validation {
    condition = contains(keys(var.zones), var.cluster.vnet) && alltrue([
      for ip in concat([var.cluster.vip, var.cluster.internal_vip], [for n in merge(var.cluster.load_balancers.nodes, var.cluster.servers.nodes, var.cluster.agents.nodes) : n.ip]) :
      cidrhost("${ip}/${split("/", var.zones[var.cluster.vnet].cidr)[1]}", 0) == cidrhost(var.zones[var.cluster.vnet].cidr, 0)
      && ip != cidrhost(var.zones[var.cluster.vnet].cidr, 1)
    ])
    error_message = "The cluster's vips and every address must be inside its vnet's zone and must not be the host's .1 — see docs/zones.md."
  }

  validation {
    condition = alltrue([
      for n in merge(var.cluster.load_balancers.nodes, var.cluster.servers.nodes, var.cluster.agents.nodes) : !contains([var.cluster.vip, var.cluster.internal_vip], n.ip)
    ]) && var.cluster.vip != var.cluster.internal_vip
    error_message = "No cluster machine may take a VIP, and the two VIPs must differ."
  }

  # One namespace and one address plan with vms, the VIPs included.
  validation {
    condition = length(setintersection(keys(var.vms), keys(merge(var.cluster.load_balancers.nodes, var.cluster.servers.nodes, var.cluster.agents.nodes)))) == 0 && length(distinct(concat(
      [for v in values(var.vms) : v.ip],
      [for n in values(merge(var.cluster.load_balancers.nodes, var.cluster.servers.nodes, var.cluster.agents.nodes)) : n.ip],
      [var.cluster.vip, var.cluster.internal_vip],
    ))) == length(var.vms) + length(var.cluster.load_balancers.nodes) + length(var.cluster.servers.nodes) + length(var.cluster.agents.nodes) + 2
    error_message = "A cluster machine or a VIP shares a name or an address with another VM."
  }
}

variable "backup" {
  description = "The daily backup of every VM to PBS: the PBS storage on the node, when it runs, and what PBS keeps."
  type = object({
    storage  = string
    schedule = string
    retention = object({
      last    = optional(number, 0)
      daily   = optional(number, 0)
      weekly  = optional(number, 0)
      monthly = optional(number, 0)
      yearly  = optional(number, 0)
    })
  })
}

variable "public_domains" {
  description = "Domains whose names the public tunnel serves. Each must be a zone in the tunnel's own Cloudflare account: a CNAME to the tunnel from another account's zone fails at the edge (1014)."
  type        = list(string)
  default     = []
}

variable "internal_domains" {
  description = "Domains of the WARP-only path: every name under them resolves to the cluster's internal_vip for WARP devices, and has no public record."
  type        = list(string)
  default     = []
}

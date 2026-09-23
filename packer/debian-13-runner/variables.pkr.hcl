# Connection. Secrets come from the environment (PKR_VAR_*), decrypted from
# secrets/tofu.sops.yaml by scripts/packer or by CI; never from a file.
variable "proxmox_url" {
  description = "Proxmox API, with the path: https://<host>/api2/json."
  type        = string
}

variable "proxmox_username" {
  description = "API token ID, user@realm!token."
  type        = string
}

variable "proxmox_token" {
  description = "API token secret."
  type        = string
  sensitive   = true
}

variable "node" {
  description = "Proxmox node the build VM runs on."
  type        = string
  default     = "pve-1"
}

# The template being built. A rebuild bumps both: Proxmox never overwrites a
# template, and VMs cloned from the previous one keep it.
variable "version" {
  description = "Template version, part of its name."
  type        = number
}

variable "vm_id" {
  description = "VMID of the resulting template, in 9000-9099."
  type        = number

  validation {
    condition     = var.vm_id >= 9000 && var.vm_id <= 9099
    error_message = "Templates use VMIDs 9000-9099."
  }
}

variable "base_template_id" {
  description = "VMID of the template the build clones: the Debian base, imported by OpenTofu."
  type        = number
  default     = 9000
}

# The throwaway build VM, reserved in docs/zones.md (build_vms).
variable "build_bridge" {
  description = "VNet of the build VM."
  type        = string
  default     = "ci"
}

variable "build_ip" {
  description = "Address of the build VM, with its prefix."
  type        = string
  default     = "10.10.1.250/24"
}

variable "build_gateway" {
  description = "Gateway of the build VM's zone."
  type        = string
  default     = "10.10.1.1"
}

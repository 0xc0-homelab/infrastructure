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

variable "commit" {
  description = "Git commit the template is built from, recorded in its description."
  type        = string
  default     = "local"
}

# The throwaway build VM, at the address reserved in docs/zones.md.
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

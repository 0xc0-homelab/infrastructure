variable "name" {
  description = "Template name in Proxmox."
  type        = string
}

variable "vm_id" {
  description = "Fixed VMID of the template. Raw images take 9000-9099; Packer's templates, 9100-9199."
  type        = number

  validation {
    condition     = var.vm_id >= 9000 && var.vm_id <= 9099
    error_message = "A raw image template takes a VMID from 9000 to 9099."
  }
}

variable "node_name" {
  description = "Proxmox node that holds the template."
  type        = string
}

variable "datastore_id" {
  description = "Datastore for the downloaded image and the template disk. It must allow the import content type."
  type        = string
}

variable "image_url" {
  description = "URL of an uncompressed cloud image (qcow2). Pin a dated build, never a 'latest' link."
  type        = string

  validation {
    condition     = can(regex("^https://", var.image_url)) && !can(regex("latest", var.image_url))
    error_message = "image_url must be https and point at a pinned, dated build — not 'latest'."
  }
}

variable "image_checksum" {
  description = "Checksum of the image, as published by the distribution, in image_checksum_algorithm."
  type        = string
}

variable "image_checksum_algorithm" {
  description = "Algorithm of image_checksum: sha512 (Debian) or sha256 (Rocky publishes only this one)."
  type        = string
  default     = "sha512"

  validation {
    condition     = contains(["sha256", "sha512"], var.image_checksum_algorithm)
    error_message = "image_checksum_algorithm must be sha256 or sha512."
  }
}

variable "disk_size_gb" {
  description = "Size of the template disk. Clones can grow it, never shrink it."
  type        = number
  default     = 8
}

variable "bridge" {
  description = "Default network for clones, which normally override it with their own zone VNet."
  type        = string
}

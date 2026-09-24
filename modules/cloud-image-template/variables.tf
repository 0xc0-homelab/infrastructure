variable "name" {
  description = "Template name in Proxmox."
  type        = string
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
  description = "SHA-512 of the image, as published by the distribution."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{128}$", var.image_checksum))
    error_message = "image_checksum must be a 128-character lowercase SHA-512."
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

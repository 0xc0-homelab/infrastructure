variable "id" {
  description = "The job's identifier in Proxmox."
  type        = string
}

variable "node_name" {
  description = "Proxmox node the job runs on."
  type        = string
}

variable "storage" {
  description = "Backup storage the job writes to: a PBS storage already configured on the node."
  type        = string
}

variable "schedule" {
  description = "When the job runs, as a Proxmox calendar event (e.g. \"03:00\" for daily at 03:00)."
  type        = string
}

variable "vm_ids" {
  description = "VMIDs of the guests the job backs up."
  type        = list(number)

  validation {
    condition     = length(var.vm_ids) > 0 && length(distinct(var.vm_ids)) == length(var.vm_ids)
    error_message = "vm_ids: at least one VMID, none repeated."
  }
}

variable "retention" {
  description = "How many backups PBS keeps per guest, by period. 0 keeps none of that period."
  type = object({
    last    = optional(number, 0)
    daily   = optional(number, 0)
    weekly  = optional(number, 0)
    monthly = optional(number, 0)
    yearly  = optional(number, 0)
  })

  validation {
    condition     = anytrue([for v in values(var.retention) : v > 0]) && alltrue([for v in values(var.retention) : v >= 0])
    error_message = "retention: no negative counts, and at least one period kept, or PBS keeps every backup forever."
  }
}

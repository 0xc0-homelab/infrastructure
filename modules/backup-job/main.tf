# One vzdump job on the node: the listed VMs, whole (data disks included), to a
# PBS storage. Snapshot mode, so the VMs keep running.
resource "proxmox_backup_job" "main" {
  id       = var.id
  node     = var.node_name
  storage  = var.storage
  schedule = var.schedule
  vmid     = [for id in var.vm_ids : tostring(id)]

  mode    = "snapshot"
  enabled = true
  # A run missed while the node was down starts as soon as it is back.
  repeat_missed = true

  prune_backups = { for k, v in var.retention : "keep-${k}" => tostring(v) if v > 0 }
}

locals {
  ssh_public_key = trimspace(
    file(pathexpand(var.ssh_public_key_file))
  )

  proxmox_ssh_host = regex("^https?://([^/:]+)", var.proxmox_endpoint)[0]

  postgres_container_fingerprint = sha256(jsonencode({
    vm_id             = var.vm_id
    node_name         = var.node_name
    hostname          = var.hostname
    unprivileged      = var.unprivileged
    os_type           = var.os_type
    template_file_url = var.template_file_url
    disk_datastore_id = var.disk_datastore_id
  }))
}
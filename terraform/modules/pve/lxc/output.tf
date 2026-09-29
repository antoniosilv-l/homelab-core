output "vm_id" {
  value       = proxmox_virtual_environment_container.lxc_container.vm_id
  description = "O ID do container LXC."
}

output "hostname" {
  value       = var.hostname
  description = "O hostname do container LXC."
}
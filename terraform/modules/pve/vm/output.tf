output "vm_name" {
  value       = proxmox_virtual_environment_vm.vm.name
  description = "O nome da VM."
}

output "vm_id" {
  value       = proxmox_virtual_environment_vm.vm.vm_id
  description = "O ID da VM."
}
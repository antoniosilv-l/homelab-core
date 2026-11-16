module "vm" {
  source = "../../../../../modules/pve/vm"

  name        = var.name
  vm_id       = var.vm_id
  node_name   = var.node_name
  description = var.description

  agent_enabled = var.agent_enabled
  agent_type    = var.agent_type

  stop_on_destroy = var.stop_on_destroy

  startup_order      = var.startup_order
  startup_up_delay   = var.startup_up_delay
  startup_down_delay = var.startup_down_delay

  os_type           = var.os_type
  content_type      = var.content_type
  template_file_url = var.template_file_url
  datastore_id      = var.datastore_id

  disk_datastore_id = var.disk_datastore_id
  disk_size         = var.disk_size
  disk_interface    = var.disk_interface

  cpu_cores   = var.cpu_cores
  cpu_sockets = var.cpu_sockets
  cpu_type    = var.cpu_type
  cpu_limit   = var.cpu_limit

  memory_dedicated = var.memory_dedicated
  memory_floating  = var.memory_floating

  network_vlan_id  = var.network_vlan_id
  network_model    = var.network_model
  network_firewall = var.network_firewall

  tpm_version = var.tpm_version

  tags = var.tags
}

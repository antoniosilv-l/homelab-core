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

  username  = var.username
  user_keys = var.user_keys

  os_type                 = var.os_type
  content_type            = var.content_type
  template_file_url       = var.template_file_url
  datastore_id            = var.datastore_id
  cloud_init_datastore_id = var.cloud_init_datastore_id
  file_name               = var.file_name

  disk_datastore_id = var.disk_datastore_id
  disk_size         = var.disk_size
  disk_interface    = var.disk_interface

  cpu_cores   = var.cpu_cores
  cpu_sockets = var.cpu_sockets
  cpu_type    = var.cpu_type
  cpu_limit   = var.cpu_limit

  memory_dedicated = var.memory_dedicated
  memory_floating  = var.memory_floating

  network_bridge   = var.network_bridge
  network_model    = var.network_model
  network_firewall = var.network_firewall

  tpm_version = var.tpm_version

  tags = var.tags
}

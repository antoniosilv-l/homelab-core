module "lxc_container" {
  source = "../../modules/pve/lxc"

  vm_id        = var.vm_id
  node_name    = var.node_name
  description  = var.description
  unprivileged = var.unprivileged
  hostname     = var.hostname
  datastore_id = var.datastore_id

  ssh_keys = [local.ssh_public_key]

  os_type           = var.os_type
  content_type      = var.content_type
  template_file_url = var.template_file_url

  disk_datastore_id = var.disk_datastore_id
  disk_size         = var.disk_size

  cpu_architecture = var.cpu_architecture
  cpu_cores        = var.cpu_cores
  cpu_limit        = var.cpu_limit

  memory_dedicated = var.memory_dedicated
  memory_swap      = var.memory_swap

  console_enabled = var.console_enabled
  console_type    = var.console_type

  tags = var.tags
}
resource "proxmox_download_file" "template_vm" {
  content_type = var.content_type
  datastore_id = var.datastore_id
  node_name    = var.node_name

  url       = var.template_file_url
  file_name = var.file_name
}

resource "proxmox_virtual_environment_file" "cloud_config" {
  count = local.is_cloud_image ? 1 : 0

  content_type = "snippets"
  datastore_id = var.cloud_init_datastore_id
  node_name    = var.node_name

  source_raw {
    data      = local.cloud_init_user_data
    file_name = "${var.vm_id}-cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  name        = var.name
  vm_id       = var.vm_id
  node_name   = var.node_name
  description = var.description
  boot_order  = local.is_cloud_image ? [var.disk_interface] : [var.disk_interface, "ide2"]

  agent {
    enabled = var.agent_enabled
    type    = var.agent_type
  }

  stop_on_destroy = var.stop_on_destroy

  startup {
    order      = var.startup_order
    up_delay   = var.startup_up_delay
    down_delay = var.startup_down_delay
  }

  initialization {

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    dynamic "user_account" {
      for_each = local.is_cloud_image ? [] : [true]

      content {
        username = var.username
        keys     = [for key_path in var.user_keys : trimspace(file(key_path))]
      }
    }

    user_data_file_id = local.is_cloud_image ? proxmox_virtual_environment_file.cloud_config[0].id : null
  }

  operating_system {
    type = var.os_type
  }

  disk {
    datastore_id = var.disk_datastore_id
    size         = var.disk_size
    interface    = var.disk_interface
    import_from  = local.is_cloud_image ? proxmox_download_file.template_vm.id : null
  }

  dynamic "cdrom" {
    for_each = local.is_cloud_image ? [] : [true]

    content {
      file_id   = proxmox_download_file.template_vm.id
      interface = "ide2"
    }
  }

  cpu {
    cores   = var.cpu_cores
    sockets = var.cpu_sockets
    type    = var.cpu_type
    limit   = var.cpu_limit
  }

  memory {
    dedicated = var.memory_dedicated
    floating  = var.memory_floating
  }

  network_device {
    bridge   = var.network_bridge
    model    = var.network_model
    firewall = var.network_firewall
  }

  tpm_state {
    version = var.tpm_version
  }

  serial_device {}

  tags = var.tags
}

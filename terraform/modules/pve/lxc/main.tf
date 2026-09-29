resource "proxmox_virtual_environment_container" "lxc_container" {
  vm_id       = var.vm_id
  node_name   = var.node_name
  description = var.description

  unprivileged = var.unprivileged
  features {
    nesting = true
  }

  initialization {
    hostname = var.hostname

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      keys     = var.ssh_keys
      password = var.root_password
    }
  }

  operating_system {
    type             = var.os_type
    template_file_id = var.template_file_id
  }

  disk {
    datastore_id = var.datastore_id
    size         = var.disk_size
  }

  cpu {
    architecture = var.cpu_architecture
    cores        = var.cpu_cores
    limit        = var.cpu_limit
  }

  memory {
    dedicated = var.memory_dedicated
    swap      = var.memory_swap
  }

  network_interface {
    name = "veth0"
  }

  console {
    enabled = var.console_enabled
    type    = var.console_type
  }

  tags = var.tags

}

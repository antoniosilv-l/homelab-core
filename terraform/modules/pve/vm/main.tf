resource "proxmox_download_file" "template_vm" {
  content_type = var.content_type
  datastore_id = var.datastore_id
  node_name    = var.node_name

  url = var.template_file_url
}

resource "proxmox_virtual_environment_vm" "vm" {
  name        = var.name
  vm_id       = var.vm_id
  node_name   = var.node_name
  description = var.description

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

  }

  operating_system {
    type = var.os_type
  }

  disk {
    datastore_id = var.disk_datastore_id
    size         = var.disk_size
    interface    = var.disk_interface
  }

  cpu {
    architecture = var.cpu_architecture
    cores = var.cpu_cores
    sockets = var.cpu_sockets
    type  = var.cpu_type
    limit = var.cpu_limit
  }

  memory {
    dedicated = var.memory_dedicated
    floating  = var.memory_floating
  }

  network_device {
    vlan_id = var.network_vlan_id
    model   = var.network_model
    firewall = var.network_firewall
    
  }

  tpm_state {
    version = var.tpm_version
  }


  tags = var.tags
}

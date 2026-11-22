locals {
  is_cloud_image = endswith(var.file_name, ".img") || endswith(var.file_name, ".qcow2")

  cloud_init_user_data = "#cloud-config\n${yamlencode({
    hostname = var.name
    users = [
      "default",
      {
        name                = var.username
        groups              = ["sudo"]
        shell               = "/bin/bash"
        ssh_authorized_keys = [for key_path in var.user_keys : trimspace(file(key_path))]
        sudo                = "ALL=(ALL) NOPASSWD:ALL"
      }
    ]
    package_update = var.agent_enabled
    packages       = var.agent_enabled ? ["qemu-guest-agent"] : []
    runcmd         = var.agent_enabled ? [["systemctl", "enable", "--now", "qemu-guest-agent.service"]] : []
  })}"
}
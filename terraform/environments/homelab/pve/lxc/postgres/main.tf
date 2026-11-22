module "lxc_container" {
  source = "../../../../../modules/pve/lxc"

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

resource "terraform_data" "postgres" {
  triggers_replace = [
    tostring(module.lxc_container.vm_id),
    local.postgres_container_fingerprint,
    filesha256("${path.module}/postgres-setup.sh"),
    sha256(var.postgres_password),
    var.postgres_allowed_cidr,
  ]

  connection {
    type    = "ssh"
    host    = local.proxmox_ssh_host
    user    = "root"
    agent   = true
    timeout = "5m"
  }

  provisioner "file" {
    source      = "${path.module}/postgres-setup.sh"
    destination = "/root/.postgres-setup-${var.vm_id}.sh"
  }

  provisioner "file" {
    content     = var.postgres_password
    destination = "/root/.postgres-password-${var.vm_id}"
  }

  provisioner "remote-exec" {
    inline = [
      "set -eu",
      "trap 'rm -f /root/.postgres-setup-${var.vm_id}.sh /root/.postgres-password-${var.vm_id}; pct exec ${var.vm_id} -- rm -f /root/.postgres-setup.sh /root/.postgres-password || true' EXIT",
      "chmod 700 /root/.postgres-setup-${var.vm_id}.sh",
      "chmod 600 /root/.postgres-password-${var.vm_id}",
      "pct push ${var.vm_id} /root/.postgres-setup-${var.vm_id}.sh /root/.postgres-setup.sh",
      "pct push ${var.vm_id} /root/.postgres-password-${var.vm_id} /root/.postgres-password",
      "pct exec ${var.vm_id} -- chmod 700 /root/.postgres-setup.sh",
      "pct exec ${var.vm_id} -- chmod 600 /root/.postgres-password",
      "pct exec ${var.vm_id} -- env POSTGRES_PASSWORD_FILE=/root/.postgres-password POSTGRES_ALLOWED_CIDR=${var.postgres_allowed_cidr} /bin/bash /root/.postgres-setup.sh",
      "pct exec ${var.vm_id} -- rm -f /root/.postgres-setup.sh /root/.postgres-password",
    ]
  }
}
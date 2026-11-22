##########################
#    Variaveis main.tf   #
##########################
variable "name" {
  description = "O nome da VM."
  type        = string
}

variable "vm_id" {
  description = "O ID da VM."
  type        = number
}

variable "node_name" {
  description = "O nome do nó Proxmox onde a VM será criado."
  type        = string
}

variable "description" {
  description = "A descrição da VM."
  type        = string
}

variable "agent_enabled" {
  description = "Habilita o dispositivo QEMU Guest Agent no Proxmox; não instala o pacote dentro do sistema convidado."
  type        = bool
  default     = true
}

variable "agent_type" {
  type    = string
  default = "virtio"

  validation {
    condition     = contains(["isa", "virtio"], var.agent_type)
    error_message = "agent_type deve ser isa ou virtio."
  }
}

variable "stop_on_destroy" {
  description = "Se a VM deve ser parada ao ser destruída."
  type        = bool
  default     = true
}

variable "startup_order" {
  description = "A ordem de inicialização da VM."
  type        = number
}

variable "startup_up_delay" {
  description = "O atraso de inicialização da VM."
  type        = number
}

variable "startup_down_delay" {
  description = "O atraso de desligamento da VM."
  type        = number
}

variable "username" {
  description = "O nome de usuário para a conta de usuário da VM."
  type        = string
}

variable "user_keys" {
  description = "As chaves SSH para a conta de usuário da VM."
  type        = list(string)

  validation {
    condition     = length(var.user_keys) > 0
    error_message = "Informe ao menos uma chave SSH pública em user_keys."
  }
}

variable "os_type" {
  description = "O tipo de sistema operacional da VM."
  type        = string
}

variable "datastore_id" {
  description = "O ID do armazenamento de dados para a VM."
  type        = string
}

variable "cloud_init_datastore_id" {
  description = "O storage Proxmox habilitado para snippets cloud-init."
  type        = string
  default     = "local"
}

variable "disk_datastore_id" {
  description = "O ID do armazenamento de dados para o disco da VM."
  type        = string
}

variable "disk_size" {
  description = "O tamanho do disco para a VM."
  type        = number
}

variable "disk_interface" {
  description = "A interface do disco para a VM."
  type        = string
}


variable "cpu_cores" {
  description = "O número de núcleos de CPU para a VM."
  type        = number
}

variable "cpu_sockets" {
  description = "O número de sockets de CPU para a VM."
  type        = number
}

variable "cpu_type" {
  description = "O tipo de CPU para a VM."
  type        = string
}

variable "cpu_limit" {
  description = "O limite de CPU para a VM."
  type        = number
}

variable "memory_dedicated" {
  description = "A quantidade de memória dedicada para a VM."
  type        = number
}

variable "memory_floating" {
  description = "A quantidade de memória swap para a VM."
  type        = number
}

variable "network_bridge" {
  description = "O ID da bridge para a interface de rede da VM."
  type        = string
}

variable "network_model" {
  description = "O modelo da interface de rede da VM."
  type        = string
}

variable "network_firewall" {
  description = "Se o firewall da interface de rede da VM deve ser habilitado."
  type        = bool
  default     = true
}

variable "tpm_version" {
  description = "A versão do TPM para a VM."
  type        = string
}

variable "tags" {
  description = "Tags para a VM."
  type        = list(string)
  default     = []
}

variable "content_type" {
  description = "Tipo da imagem baixada: iso para mídia de instalação ou import para imagem de disco."
  type        = string
}

variable "file_name" {
  description = "O nome do arquivo de template a ser baixado."
  type        = string
}

variable "template_file_url" {
  description = "A URL do arquivo de template a ser baixado."
  type        = string
}
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
  description = "Se o agente da VM deve ser habilitado."
  type        = bool
  default     = true
}

variable "agent_type" {
  description = "O tipo de agente da VM."
  type        = string
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

variable "os_type" {
  description = "O tipo de sistema operacional da VM."
  type        = string
}

variable "datastore_id" {
  description = "O ID do armazenamento de dados para a VM."
  type        = string
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

variable "cpu_architecture" {
  description = "A arquitetura da CPU para a VM."
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

variable "network_vlan_id" {
  description = "O ID da VLAN para a interface de rede da VM."
  type        = number
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
  description = "O tipo de conteúdo do arquivo a ser baixado."
  type        = string
}

variable "template_file_url" {
  description = "A URL do arquivo de template a ser baixado."
  type        = string
}
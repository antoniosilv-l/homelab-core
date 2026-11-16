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
  description = "O nome do nó Proxmox onde a VM será criada."
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
  description = "O ID do datastore onde a VM será criada."
  type        = string
}

variable "disk_datastore_id" {
  description = "O ID do datastore onde o disco da VM será criado."
  type        = string
}

variable "disk_size" {
  description = "O tamanho do disco da VM em GB."
  type        = number
}

variable "disk_interface" {
  description = "O tipo de interface do disco da VM."
  type        = string
}

variable "cpu_cores" {
  description = "O número de núcleos da CPU da VM."
  type        = number
}

variable "cpu_sockets" {
  description = "O número de soquetes da CPU da VM."
  type        = number
}

variable "cpu_type" {
  description = "O tipo de CPU da VM."
  type        = string
}

variable "cpu_limit" {
  description = "O limite de CPU da VM."
  type        = number
}

variable "memory_dedicated" {
  description = "A quantidade de memória dedicada da VM em MB."
  type        = number
}

variable "memory_floating" {
  description = "A quantidade de memória flutuante da VM em MB."
  type        = number
}

variable "network_vlan_id" {
  description = "O ID da VLAN da interface de rede da VM."
  type        = number
}

variable "network_model" {
  description = "O modelo da interface de rede da VM."
  type        = string
}

variable "network_firewall" {
  description = "Se o firewall da interface de rede da VM deve ser habilitado."
  type        = bool
  default     = false
}

variable "tpm_version" {
  description = "A versão do TPM (Trusted Platform Module) da VM."
  type        = string
  default     = ""
}

variable "tags" {
  description = "As tags associadas à VM."
  type        = list(string)
  default     = []
}

variable "content_type" {
  description = "O tipo de conteúdo da VM."
  type        = string
}

variable "template_file_url" {
  description = "A URL do arquivo de template da VM."
  type        = string
}

##########################
# Variaveis providers.tf #
##########################

variable "proxmox_endpoint" {
  description = "O endpoint da API do Proxmox."
  type        = string
}

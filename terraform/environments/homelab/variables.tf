##########################
#    Variaveis main.tf   #
##########################
variable "vm_id" {
  description = "O ID do container LXC."
  type        = number
}

variable "node_name" {
  description = "O nome do nó Proxmox onde o container LXC será criado."
  type        = string
}

variable "description" {
  description = "A descrição do container LXC."
  type        = string
}

variable "unprivileged" {
  description = "Se o container LXC deve ser não privilegiado."
  type        = bool
  default     = true
}

variable "hostname" {
  description = "O hostname do container LXC."
  type        = string
}

variable "ssh_public_key_file" {
  description = "Caminho para a chave SSH pública usada no container LXC."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "os_type" {
  description = "O tipo de sistema operacional do container LXC."
  type        = string
}

variable "datastore_id" {
  description = "O ID do armazenamento de dados para o container LXC."
  type        = string
}

variable "disk_datastore_id" {
  description = "O ID do armazenamento de dados para o disco do container LXC."
  type        = string
}

variable "disk_size" {
  description = "O tamanho do disco para o container LXC."
  type        = number
}

variable "cpu_architecture" {
  description = "A arquitetura da CPU para o container LXC."
  type        = string
}

variable "cpu_cores" {
  description = "O número de núcleos de CPU para o container LXC."
  type        = number
}

variable "cpu_limit" {
  description = "O limite de CPU para o container LXC."
  type        = number
}

variable "memory_dedicated" {
  description = "A quantidade de memória dedicada para o container LXC."
  type        = number
}

variable "memory_swap" {
  description = "A quantidade de memória swap para o container LXC."
  type        = number
}

variable "console_enabled" {
  description = "Se o container LXC deve ter o console habilitado."
  type        = bool
  default     = true
}

variable "console_type" {
  description = "O tipo de console para o container LXC."
  type        = string
  default     = "shell"
}

variable "tags" {
  description = "Tags para o container LXC."
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

##########################
# Variaveis providers.tf #
##########################

variable "proxmox_endpoint" {
  description = "O endpoint da API do Proxmox."
  type        = string
}

variable "proxmox_api_token" {
  description = "O token de API do Proxmox."
  type        = string
  sensitive   = true
}
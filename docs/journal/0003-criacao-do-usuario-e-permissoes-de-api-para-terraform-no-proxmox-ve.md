# 0003 — Criação do usuário e permissões de API para Terraform no Proxmox VE

**Status:** Concluído

## Objetivo

Criar uma identidade específica para o Terraform no Proxmox VE, utilizando API Token com privilégio separado (`Privilege Separation`), evitando o uso de `root@pam` nas automações.

A configuração foi projetada seguindo o princípio de menor privilégio possível, permitindo ao Terraform:

* consultar o Proxmox VE;
* baixar templates LXC por URL;
* criar e configurar containers LXC;
* utilizar o storage destinado aos templates;
* utilizar o storage destinado aos discos dos containers;
* utilizar a bridge `vmbr0`;
* controlar o ciclo de vida dos containers.

## Cenário

O Terraform utiliza o Proxmox VE através da API:

```text
https://192.168.88.2:8006/api2/json
```

O node do Proxmox é:

```text
srv
```

O objetivo é permitir que o Terraform crie containers sem utilizar:

```text
root@pam
```

Para isso foi criado:

```text
Usuário: terraform@pve
Token: terraform
```

O token foi criado com **Privilege Separation habilitado**.

## O que foi feito

1. Criação do usuário dedicado:

```text
terraform@pve
```

2. Criação de um API Token específico para Terraform:

```text
terraform@pve!terraform
```

3. `Privilege Separation` mantido habilitado para impedir que o token receba permissões além das explicitamente atribuídas.

4. Criação de uma role específica:

```text
TerraformLXC
```

5. Inclusão das permissões necessárias para:

   * criação e configuração de containers;
   * gerenciamento de CPU, memória, disco e rede;
   * inicialização/cloud-init;
   * gerenciamento de energia;
   * auditoria;
   * utilização da rede;
   * download de templates;
   * utilização dos storages.

6. Aplicação da role tanto ao **usuário** quanto ao **API Token**, devido ao uso de `Privilege Separation`.

7. Aplicação das ACLs nos paths necessários do Proxmox:

   * `/nodes/srv`
   * `/vms`
   * `/storage/local`
   * `/storage/local-lvm`
   * `/sdn/zones/localnetwork/vmbr0`

8. Validação das permissões efetivas do usuário e do token.

9. Teste da API `query-url-metadata`, utilizado pelo Terraform para consultar templates antes do download.

10. Validação da criação completa do container LXC via Terraform.

## Role utilizada

A role `TerraformLXC` foi criada para concentrar as permissões necessárias à automação.

A composição utilizada inclui:

```text
Datastore.Audit
Datastore.AllocateSpace
Datastore.AllocateTemplate

SDN.Use

Sys.AccessNetwork
Sys.Audit
Sys.Console

VM.Allocate
VM.Audit
VM.Config.CPU
VM.Config.Cloudinit
VM.Config.Disk
VM.Config.Memory
VM.Config.Network
VM.Config.Options
VM.PowerMgmt
```

A role pode ser criada/ajustada com:

```bash
pveum role add TerraformLXC \
  -privs "Datastore.Audit,Datastore.AllocateSpace,Datastore.AllocateTemplate,SDN.Use,Sys.AccessNetwork,Sys.Audit,Sys.Console,VM.Allocate,VM.Audit,VM.Config.CPU,VM.Config.Cloudinit,VM.Config.Disk,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.PowerMgmt"
```

Caso a role já exista:

```bash
pveum role modify TerraformLXC \
  -privs "Datastore.Audit,Datastore.AllocateSpace,Datastore.AllocateTemplate,SDN.Use,Sys.AccessNetwork,Sys.Audit,Sys.Console,VM.Allocate,VM.Audit,VM.Config.CPU,VM.Config.Cloudinit,VM.Config.Disk,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.PowerMgmt"
```

## ACLs do usuário

Como o token possui `Privilege Separation`, as permissões precisam existir no usuário pai e também estar disponíveis ao token.

### Node

```bash
pveum acl modify /nodes/srv \
  -user terraform@pve \
  -role TerraformLXC
```

### VMs e containers

```bash
pveum acl modify /vms \
  -user terraform@pve \
  -role TerraformLXC
```

### Storage de templates

```bash
pveum acl modify /storage/local \
  -user terraform@pve \
  -role TerraformLXC
```

### Storage dos discos dos containers

```bash
pveum acl modify /storage/local-lvm \
  -user terraform@pve \
  -role TerraformLXC
```

### Bridge de rede

```bash
pveum acl modify /sdn/zones/localnetwork/vmbr0 \
  -user terraform@pve \
  -role TerraformLXC
```

## ACLs do API Token

Como o token foi criado com `Privilege Separation`, a mesma role também foi associada diretamente ao token.

### Node

```bash
pveum acl modify /nodes/srv \
  -token 'terraform@pve!terraform' \
  -role TerraformLXC
```

### VMs e containers

```bash
pveum acl modify /vms \
  -token 'terraform@pve!terraform' \
  -role TerraformLXC
```

### Storage de templates

```bash
pveum acl modify /storage/local \
  -token 'terraform@pve!terraform' \
  -role TerraformLXC
```

### Storage dos discos

```bash
pveum acl modify /storage/local-lvm \
  -token 'terraform@pve!terraform' \
  -role TerraformLXC
```

### Bridge de rede

```bash
pveum acl modify /sdn/zones/localnetwork/vmbr0 \
  -token 'terraform@pve!terraform' \
  -role TerraformLXC
```

## Problemas encontrados e soluções

| Problema                                                                                 | Causa                                                                                        | Solução                                                                          |
| ---------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| Terraform conseguia consultar `/nodes`, mas não conseguia consultar `query-url-metadata` | O token não possuía `Sys.AccessNetwork`                                                      | Inclusão de `Sys.AccessNetwork` na role e associação ao node                     |
| `query-url-metadata` retornava `Permission check failed`                                 | Token com `Privilege Separation` não possuía ACL própria suficiente                          | Aplicar a role também diretamente ao API Token                                   |
| Download do template funcionava, mas criação do LXC retornava HTTP 403                   | Permissões de `VM.*` estavam aplicadas somente em `/nodes/srv`                               | Aplicar a role também em `/vms`                                                  |
| Criação do container ainda dependia da rede do host                                      | Falta de permissão para utilizar a bridge                                                    | Aplicar `SDN.Use` em `/sdn/zones/localnetwork/vmbr0`                             |
| Terraform precisava utilizar dois storages diferentes                                    | Template e disco do LXC possuem finalidades diferentes                                       | Conceder permissões em `/storage/local` e `/storage/local-lvm`                   |
| Usuário possuía role, mas token continuava sem acesso                                    | `Privilege Separation` limita o token às permissões efetivamente concedidas ao próprio token | ACL configurada tanto para `terraform@pve` quanto para `terraform@pve!terraform` |

## Validação das permissões

### Permissões do usuário

```bash
pveum user permissions terraform@pve
```

### Permissões do token

```bash
pveum user token permissions terraform@pve terraform
```

O resultado final deve conter ACLs equivalentes a:

```text
/nodes/srv
/storage/local
/storage/local-lvm
/sdn/zones/localnetwork/vmbr0
/vms
```

com as permissões definidas pela role `TerraformLXC`.

## Teste da API de metadata

Antes da execução do Terraform, foi utilizado o endpoint:

```text
/api2/json/nodes/srv/query-url-metadata
```

Teste:

```bash
curl -k \
  -H 'Authorization: PVEAPIToken=terraform@pve!terraform=SEU_SECRET' \
  --get \
  --data-urlencode 'url=http://download.proxmox.com/images/system/alpine-3.24-default_20260714_amd64.tar.xz' \
  https://192.168.88.2:8006/api2/json/nodes/srv/query-url-metadata
```

A operação passou a funcionar após a correção das ACLs.

## Integração com Terraform

O Terraform utiliza o usuário/token dedicado:

```text
terraform@pve!terraform
```

O token não deve ser armazenado diretamente em arquivos `.tf` ou `.tfvars`.

A credencial deve ser fornecida através de variável de ambiente:

```bash
export PROXMOX_VE_API_TOKEN='terraform@pve!terraform=SEU_SECRET'
```

O provider Proxmox é configurado no root module:

```hcl
provider "proxmox" {
  endpoint = var.proxmox_endpoint
}
```

O módulo LXC não recebe diretamente o token como variável. O provider é herdado pelo módulo filho.

## Arquitetura de permissões

A configuração final ficou conceitualmente:

```text
terraform@pve
│
├── /nodes/srv
│   └── TerraformLXC
│
├── /vms
│   └── TerraformLXC
│
├── /storage/local
│   └── TerraformLXC
│
├── /storage/local-lvm
│   └── TerraformLXC
│
└── /sdn/zones/localnetwork/vmbr0
    └── TerraformLXC

terraform@pve!terraform
│
├── /nodes/srv
│   └── TerraformLXC
│
├── /vms
│   └── TerraformLXC
│
├── /storage/local
│   └── TerraformLXC
│
├── /storage/local-lvm
│   └── TerraformLXC
│
└── /sdn/zones/localnetwork/vmbr0
    └── TerraformLXC
```

## Resultado

O Terraform passou a ser capaz de:

```text
Git / Terraform
       │
       ▼
Proxmox API
       │
       ├── consultar node
       ├── consultar metadata
       ├── baixar template LXC
       ├── criar container
       ├── configurar CPU
       ├── configurar memória
       ├── configurar disco
       ├── configurar rede
       └── iniciar/parar container
```

sem utilizar `root@pam`.

O primeiro container LXC foi criado com sucesso utilizando exclusivamente o usuário/token dedicado do Terraform.

## Observação de segurança

O secret do API Token nunca deve ser armazenado no repositório Git, em `terraform.tfvars`, em arquivos `.tf` ou diretamente em código-fonte.

Como a credencial utilizada durante os testes foi exposta durante a configuração, ela deve ser considerada comprometida e substituída por um novo API Token antes de ser utilizada na pipeline DevSecOps definitiva.

A credencial definitiva deverá ser fornecida por secret manager ou variável protegida do sistema de CI/CD.

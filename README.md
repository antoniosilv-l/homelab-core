# homelab-core

![Status](https://img.shields.io/badge/status-em%20desenvolvimento-yellow)
![Proxmox VE](https://img.shields.io/badge/Hypervisor-Proxmox%20VE-orange)
![Terraform](https://img.shields.io/badge/IaC-Terraform-844FBA?logo=terraform)
![Ansible](https://img.shields.io/badge/Configura%C3%A7%C3%A3o-Ansible-EE0000?logo=ansible)

![Diagrama da arquitetura do homelab](docs/architecture/homelab.svg)

**Arquivo editável:** [homelab.drawio](docs/architecture/homelab.drawio)

## Objetivo

Construir um ambiente de laboratório que possa ser provisionado, configurado e documentado de forma repetível. A ideia é reduzir etapas manuais, organizar a infraestrutura em código e criar uma base para experimentar práticas de segurança ao longo do ciclo de vida da infraestrutura.

## Ambiente

> Sendo atualizada conforme desenvolvimento.

| Componente | Especificação | Papel |
|---|---|---|
| Estação principal | Nobara Linux, AMD Ryzen 7 5700X3D, 32 GB RAM, NVIDIA GeForce RTX 4070 SUPER | Administração, desenvolvimento e execução das ferramentas de automação |
| Nó do homelab 1 | Lenovo ThinkCentre, Intel Core i5-8400T, 8 GB RAM | Host de virtualização |
| Nó do homelab 2 | ... | ... |
| Nó do homelab 3 | ... | ... |
| Nas Storage | ... | ... |
| Hipervisor | Proxmox VE | Gerenciamento de máquinas virtuais e containers LXC |
| Rede | MikroTik | Conectividade local e bootstrap de instalação via rede |

## Estrutura do projeto

A organização em desenvolvimento separa os arquivos de infraestrutura, automação e documentação:

```text
.
├── ansible/
│   ├── inventory/
│   │   ├── generated/
│   │   └── group_vars/
│   ├── playbooks/
│   └── roles/
│       ├── common/
│       ├── docker/
│       └── webapp/
├── docs/
│    ├── homelab.drawio
│    └── homelab.png
│   ├── journal/
│   └── runbooks/
└── terraform/
    ├── environments/
    │   └── homelab/
    └── modules/
        ├── ansible-inventory/
        └── pve/
            ├── lxc/
            └── vm/
```

> A estrutura acima reflete a organização local planejada para o projeto. Os arquivos serão publicados e consolidados no repositório conforme forem revisados.

## Tecnologias e ferramentas

> Sendo atualizada conforme desenvolvimento.

- **Proxmox VE** para virtualização.
- **Terraform** para provisionamento declarativo dos recursos.
- **Ansible** para configuração dos sistemas e serviços.
- **MikroTik, DHCP, TFTP e PXE** para a inicialização e instalação pela rede.
- **Checkov e Trivy**, planejados para adicionar verificações de segurança à automação.
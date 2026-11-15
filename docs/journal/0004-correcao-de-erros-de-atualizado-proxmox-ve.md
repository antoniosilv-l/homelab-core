# 0002 — Correção de erros de atualização do Proxmox VE (APT / Repositórios Enterprise)

**Status:** Concluído

## Objetivo

Corrigir falhas na atualização dos repositórios e pacotes do Proxmox VE, identificadas durante a execução do `apt-get update`, que retornava `exit code 100`.

O objetivo foi remover a dependência de repositórios Enterprise que exigem assinatura paga, mantendo os repositórios oficiais gratuitos (No-Subscription), sem reinstalar o sistema ou comprometer os serviços existentes.

## O que foi feito

1. Investigação inicial do erro `TASK ERROR: command 'apt-get update' failed: exit code 100`, apresentado pelo Proxmox.
2. Identificação de que o servidor utiliza Debian 13 (Trixie), com repositórios configurados no formato moderno `.sources`, e não no formato tradicional `sources.list`.
3. Identificação dos arquivos de configuração existentes:
   - `/etc/apt/sources.list.d/debian.sources`
   - `/etc/apt/sources.list.d/ceph.sources`
   - `/etc/apt/sources.list.d/pve-enterprise.sources`
4. Desativação do repositório Enterprise do Proxmox, que retornava `401 Unauthorized` por exigir assinatura.
5. Criação do repositório gratuito `pve-no-subscription`, apontando para a versão Trixie.
6. Identificação de que o repositório Enterprise do Ceph também estava ativo e exigia autenticação.
7. Substituição da configuração Enterprise do Ceph pelo repositório gratuito `no-subscription`.
8. Remoção do arquivo ativo `pve-enterprise.sources` do caminho de configuração do APT, mantendo-o como `.disabled`.
9. Limpeza do cache de pacotes e atualização dos índices do APT.

## Dificuldades encontradas e como superamos

| Problema | Causa | Solução |
| --- | --- | --- |
| `TASK ERROR: command 'apt-get update' failed: exit code 100` | Falha na atualização de um ou mais repositórios APT | Investigar os repositórios e identificar as fontes que retornavam erro |
| `cat: /etc/apt/sources.list: No such file or directory` | O Debian 13 utiliza configuração de repositórios no formato `.sources` | Consultar os arquivos dentro de `/etc/apt/sources.list.d/` |
| `sed: can't read .../pve-enterprise.list: No such file or directory` | O arquivo existente era `pve-enterprise.sources`, não `.list` | Utilizar o caminho correto do arquivo `.sources` |
| `401 Unauthorized` no repositório Enterprise do PVE | O repositório Enterprise exige assinatura válida do Proxmox | Desativar `pve-enterprise.sources` e utilizar `pve-no-subscription` |
| `401 Unauthorized` no repositório Enterprise do Ceph | O arquivo `ceph.sources` apontava para `enterprise.proxmox.com/debian/ceph-squid` | Substituir o repositório Enterprise pelo endereço gratuito do Ceph |
| `The repository ... is not signed` | O APT não conseguiu obter os metadados autenticados porque o servidor Enterprise recusou o acesso | Remover a dependência dos repositórios Enterprise, mantendo a validação GPG normal |
| Possibilidade de utilizar uma versão incorreta do repositório | O servidor poderia utilizar Debian Bookworm ou Trixie | Consultar `/etc/os-release` e confirmar Debian 13 (Trixie) antes de configurar os repositórios |

## Comandos e arquivos principais

**1\. Identificação da versão do sistema:**

bash

```bash
cat /etc/os-release
```

Resultado identificado:

text

```text
PRETTY_NAME="Debian GNU/Linux 13 (trixie)"
VERSION_ID="13"
VERSION_CODENAME=trixie
```

**2\. Desativação do repositório Enterprise do PVE:**

bash

```bash
sed -i 's/Enabled: yes/Enabled: no/' \
  /etc/apt/sources.list.d/pve-enterprise.sources
```

Posteriormente, o arquivo foi renomeado para não ser interpretado pelo APT:

bash

```bash
mv /etc/apt/sources.list.d/pve-enterprise.sources \
   /etc/apt/sources.list.d/pve-enterprise.sources.disabled
```

**3\. Configuração do repositório gratuito do Proxmox:**

Arquivo: `/etc/apt/sources.list.d/pve-no-subscription.sources`

text

```text
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
```

**4\. Configuração do repositório gratuito do Ceph:**

Arquivo: `/etc/apt/sources.list.d/ceph.sources`

text

```text
Types: deb
URIs: http://download.proxmox.com/debian/ceph-squid
Suites: trixie
Components: no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
```

**5\. Limpeza e atualização dos índices:**

bash

```bash
apt clean
rm -rf /var/lib/apt/lists/*
apt update
```

**6\. Atualização dos pacotes (após confirmar que o****`apt update`****terminou sem erros):**

bash

```bash
apt full-upgrade -y
```

**7\. Verificação da versão do Proxmox:**

bash

```bash
pveversion
```

## Estado final esperado

- Debian 13 (Trixie) mantido como versão base do sistema.
- Repositório oficial gratuito `pve-no-subscription` configurado.
- Repositório Enterprise do PVE desativado.
- Repositório gratuito `no-subscription` do Ceph configurado.
- Repositórios Debian mantidos intactos.
- Chaves GPG oficiais preservadas.
- Atualização dos índices do APT sem erros `401 Unauthorized`.

**Observação:** O `apt update` apresentou resultado positivo para os repositórios Debian e PVE No-Subscription após a primeira correção. Os erros restantes foram identificados no Ceph Enterprise e no PVE Enterprise. As alterações finais foram aplicadas para eliminar essas duas fontes de erro; a conclusão definitiva deve ser validada com uma nova execução de `apt update`.

## Referências

- [Proxmox VE — Package Repositories (documentação oficial)](<https://pve.proxmox.com/wiki/Package_Repositories>)
- [Proxmox VE — Ceph Documentation](<https://pve.proxmox.com/pve-docs/>)
- [Debian — APT Sources.list Format](<https://manpages.debian.org/trixie/apt/sources.list.5.en.html>)
- [Proxmox — Download](<https://www.proxmox.com/en/downloads>)
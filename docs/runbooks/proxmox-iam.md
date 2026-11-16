# Usuários, roles e tokens no Proxmox

O script [`scripts/proxmox-iam.sh`](../../scripts/proxmox-iam.sh) cria e remove
identidades do Proxmox VE de forma idempotente. Execute-o como `root` em um nó
PVE 8.x ou 9.x; em clusters, o quorum é obrigatório. Ele usa `pveum`,
`pveversion`, `awk`, `grep`, `flock`, `logger`, `chmod` e `date`, além de
`pvecm` em clusters. Para `--realm pam`, também usa `getent` e `chpasswd`.

## Perfis incluídos

| Perfil | Role PVE | Escopo padrão | Token |
|---|---|---|---|
| `terraform-api` | `TerraformAPI` customizada | `/` | Sim, `privsep=0`, expira em um ano |
| `ansible-api` | `AnsibleAPI` customizada | `/` | Sim, `privsep=0`, expira em um ano |
| `usuario-comum` | `PVEVMUser` nativa | `/pool/<nome>` | Sim, `privsep=1`, expira em um ano |
| `auditoria` | `PVEAuditor` nativa | `/` | Sim, `privsep=1`, expira em um ano |

`usuario-comum` não recebe permissões de storage para ISO; conceda-as
separadamente somente se o fluxo do usuário precisar delas.

`TerraformAPI` inclui as permissões para provisionamento de VMs/LXC, template,
storage e SDN registradas no catálogo do script. Usa `VM.Monitor` no PVE 8 e
`VM.GuestAgent.Audit` no PVE 9. `AnsibleAPI` permite auditoria e gerenciamento
de energia de VMs; ajuste o catálogo após validar os módulos e endpoints
efetivamente usados.

Os perfis de automação têm `/` como caminho padrão por compatibilidade, mas
isso concede escopo amplo. Prefira caminhos mais restritos para o seu ambiente.
O `--path` pode ser informado em execuções repetidas de `create` para adicionar
ACLs em vários caminhos. No homelab documentado, os caminhos usados pelo
Terraform incluem `/nodes/srv`, `/vms`, `/storage/local`,
`/storage/local-lvm` e `/sdn/zones/localnetwork/vmbr0`; confirme-os antes de
aplicar. A role customizada é compartilhada e não é removida pelo comando
`delete`.

## Exemplos

Confira o catálogo e revise a operação antes de executá-la:

```bash
./scripts/proxmox-iam.sh list-roles
./scripts/proxmox-iam.sh create --role terraform-api --name terraform --dry-run
```

`create` cria o usuário, associa-o ao grupo do perfil e emite um API token com
o mesmo nome do usuário por padrão. O grupo padrão é `grp-<perfil>`; use
`--group` para escolher outro. O grupo será criado se ainda não existir e
reutilizado se já existir. O token expira em um ano; `--token-name`, `--privsep`
e `--expire` permitem personalizar esses valores. O segredo é exibido uma única
vez, ou pode ser salvo em um arquivo novo com modo `0600`:

```bash
./scripts/proxmox-iam.sh create --role terraform-api --name terraform \
  --group grp-terraform-lab --path /vms \
  --output /root/terraform-token.secret
```

O grupo é compartilhado; usuários criados com o mesmo `--group` são associados
a ele. Grupos personalizados informados com `--group` são preservados pelo
comando `delete`, mesmo quando ficam vazios. Sem `--group`, usuários do mesmo
perfil usam o grupo padrão (`grp-terraform-api`, `grp-auditoria` etc.), que é
removido pelo `delete` quando não possui mais membros. Se o usuário ou token já
existir, o script preserva a identidade e não consegue recuperar o segredo
anterior do token. A existência de roles, grupos, usuários e tokens é conferida
no `/etc/pve/user.cfg` e, quando necessário, na listagem do `pveum`. O arquivo
também é a fonte das associações de grupo e permite reconhecer usuários sem
tokens, sem depender de uma tabela vazia do `pveum user token list`. Se uma
execução for interrompida após criar o usuário, execute novamente o mesmo
comando `create`: ele reutiliza o usuário e conclui a associação ao grupo, ACL e
token pendentes.

Para acrescentar outras ACLs à mesma identidade, execute novamente com cada
caminho necessário:

```bash
./scripts/proxmox-iam.sh create --role terraform-api --name terraform \
  --path /nodes/srv --yes
```

Crie um usuário humano. O arquivo deve conter a senha em uma única linha; use
`--password-file -` para lê-la de stdin. A senha não é passada em argumentos:

```bash
./scripts/proxmox-iam.sh create --role usuario-comum --name pessoa \
  --path /pool/lab --password-file /root/pessoa-password \
  --output /root/pessoa-token.secret
```

Com `--realm pam`, a conta Linux precisa existir previamente; o script entrega a
senha ao `chpasswd` por stdin. A role não configura 2FA: habilite o segundo fator
separadamente para as contas humanas.

Consulte o estado ou remova um usuário e todos os seus tokens:

```bash
./scripts/proxmox-iam.sh show --role auditoria --name leitura
./scripts/proxmox-iam.sh delete --role terraform-api --name terraform --dry-run
./scripts/proxmox-iam.sh delete --role terraform-api --name terraform
```

Use `--yes` somente depois de revisar o `--dry-run`. Tokens existentes não
podem ter o segredo recuperado; o script não os recria nem altera sua expiração,
e falha se o `privsep` não corresponder ao solicitado. `--output` exige um
arquivo inexistente e grava o segredo com modo `0600`. Armazene-o em um cofre
de segredos e remova cópias temporárias. `--expire 0` desativa a expiração do
token; use essa opção somente quando necessário.

## Reset do IAM do Proxmox

O comando `reset` remove usuários configurados no Proxmox que não sejam
`root@...`, seus API tokens, ACLs associados e grupos que não contenham uma
identidade root. Também remove roles customizadas que não estejam sendo usadas
por ACLs preservadas de root. Usuários root, tokens root, grupos que contenham
root e as roles necessárias às ACLs desses usuários são mantidos.

O reset não remove contas do Linux/PAM nem apaga arquivos do nó. Primeiro revise
o inventário:

```bash
./scripts/proxmox-iam.sh reset --dry-run
```

Para executar, rode sem `--dry-run` e digite `RESET` no terminal quando
solicitado. `--yes` não é aceito nesse comando; o reset não pode ser executado
sem terminal interativo. O script interrompe a operação se não conseguir ler
`/etc/pve/user.cfg` ou interpretar a listagem de ACLs. Ainda assim, faça backup
da configuração e valide o plano antes da execução no nó correto.

O provider bpg do Terraform pode usar SSH em algumas operações; um token de API
não substitui essa configuração. Um erro 403 pode indicar privilégio ausente:
valide as operações necessárias no laboratório antes de ampliar a role. A
compatibilidade indicada no cabeçalho ainda precisa ser testada em nós PVE 8 e 9.

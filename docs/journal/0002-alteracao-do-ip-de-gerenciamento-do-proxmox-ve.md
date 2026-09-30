# 0002 — Alteração do IP de gerenciamento do Proxmox VE

**Status:** Concluído

## Objetivo

Alterar o endereço IP de gerenciamento do Proxmox VE para colocá-lo na mesma rede LAN do MikroTik e do PC principal, permitindo acesso à interface web e administração do hypervisor sem necessidade de roteamento adicional entre sub-redes.

## Cenário inicial

O Proxmox VE havia sido instalado anteriormente utilizando um endereço IP padrão definido pelo processo de instalação via rede/PXE:

```text
PVE
vmbr0 → 192.168.100.2/24
Gateway → 192.168.100.1
```

O MikroTik, após o reset para configuração de fábrica, estava utilizando a rede padrão:

```text
MikroTik → 192.168.88.1/24
PC principal → 192.168.88.254/24
```

Como o PVE estava na rede `192.168.100.0/24` e o PC na rede `192.168.88.0/24`, o acesso direto ao Proxmox não funcionava.

## O que foi feito

1. Identificação do endereço atual e da rota configurada no PVE:

```text
vmbr0 → 192.168.100.2/24
rota → 192.168.100.1 dev vmbr0
```

2. Decisão de manter inicialmente toda a infraestrutura do homelab na mesma rede LAN do MikroTik, evitando introduzir roteamento ou VLANs antes da configuração básica estar estabilizada.

3. Alteração do endereço da bridge `vmbr0` do Proxmox para:

```text
IP → 192.168.88.2/24
Gateway → 192.168.88.1
```

4. Aplicação da nova configuração de rede do Proxmox.

5. Validação da conectividade entre:

   * PC principal → Proxmox VE
   * Proxmox VE → MikroTik

6. Validação do acesso à interface web do Proxmox pela porta padrão `8006`.

## Topologia após a alteração

```text
                    MikroTik
                 192.168.88.1
                      │
          ┌───────────┴───────────┐
          │                       │
         PC                      PVE
192.168.88.254              192.168.88.2
          │                       │
          │                      vmbr0
          │                       │
          └──────── LAN ──────────┘
```

A rede de gerenciamento passou a ser:

```text
192.168.88.0/24
```

## Dificuldade encontrada e solução

| Problema                                                         | Causa                                                                                     | Solução                                                                        |
| ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| Interface web do PVE não era acessível pelo PC                   | PVE estava em `192.168.100.0/24`, enquanto o PC e o MikroTik estavam em `192.168.88.0/24` | Alterar o IP da `vmbr0` para `192.168.88.2/24` e o gateway para `192.168.88.1` |
| Rota padrão do PVE apontava para uma rede diferente da LAN atual | Gateway configurado como `192.168.100.1`                                                  | Alterar o gateway para `192.168.88.1`                                          |

## Configuração de rede

A configuração da bridge `vmbr0` foi ajustada no arquivo:

```text
/etc/network/interfaces
```

A configuração final esperada é equivalente a:

```text
auto lo
iface lo inet loopback

iface <interface-fisica> inet manual

auto vmbr0
iface vmbr0 inet static
    address 192.168.88.2/24
    gateway 192.168.88.1
    bridge-ports <interface-fisica>
    bridge-stp off
    bridge-fd 0
```

Os valores de `<interface-fisica>` devem ser preservados conforme a interface física já utilizada pelo PVE.

## Aplicação da configuração

Após a alteração do arquivo `/etc/network/interfaces`, a configuração pode ser recarregada com:

```bash
ifreload -a
```

Como a alteração modifica o endereço da interface de gerenciamento, a sessão SSH existente pode ser interrompida durante a aplicação.

## Validação

### Verificação do endereço da bridge

```bash
ip -br addr
```

Resultado esperado:

```text
vmbr0    UP    192.168.88.2/24
```

### Verificação da tabela de rotas

```bash
ip route
```

Resultado esperado:

```text
default via 192.168.88.1 dev vmbr0
192.168.88.0/24 dev vmbr0
```

### Teste de conectividade com o MikroTik

```bash
ping -c 4 192.168.88.1
```

### Teste de conectividade a partir do PC

```bash
ping 192.168.88.2
```

### Acesso à interface web

```text
https://192.168.88.2:8006
```

O acesso à interface web do Proxmox foi validado com sucesso.

## Resultado

O Proxmox VE passou a utilizar um endereço estático pertencente à mesma rede LAN do MikroTik e do PC principal:

```text
MikroTik → 192.168.88.1
PVE      → 192.168.88.2
PC       → 192.168.88.254
```

A alteração eliminou a necessidade de roteamento entre `192.168.100.0/24` e `192.168.88.0/24` para o acesso administrativo inicial.

## Próximos passos

A rede `192.168.88.0/24` será utilizada inicialmente como rede de gerenciamento do homelab. Em uma etapa posterior, a infraestrutura poderá ser segmentada utilizando VLANs e sub-redes distintas para gerenciamento, servidores, containers, IoT e dispositivos convidados.

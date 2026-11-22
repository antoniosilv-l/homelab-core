# 0005 — Diagnóstico de VLAN e DHCP da VM Debian no Proxmox

**Status:** Concluído

## Objetivo

Investigar por que a VM `debian-hom` (ID `100`) não recebia endereço DHCP e
configurar sua interface de rede para a LAN existente do homelab.

## Cenário

A VM foi criada pelo Terraform no Proxmox VE com:

- interface de rede VirtIO conectada à bridge `vmbr0`;
- configuração de rede via cloud-init, usando DHCP;
- usuário cloud-init `antlss` e chave pública SSH;
- disco do sistema importado de uma imagem `qcow2`.

A rede principal do homelab é `192.168.88.0/24`, servida pelo MikroTik.

## Sintomas

A VM iniciava, mas não recebia endereço IP. Como consequência, não era possível
acessá-la por SSH e o QEMU Guest Agent não respondia. O MAC da interface também
não aparecia na tabela ARP do host.

O Proxmox observava tráfego DHCP saindo da VM, mas o MikroTik não apresentava
um lease correspondente. As mensagens `cfg80211: failed to load
regulatory.db` e `Guest Agent is not running` foram investigadas, mas não eram
a causa do problema de DHCP.

## Diagnóstico

Inicialmente, a interface da VM estava configurada com a VLAN 100:

```text
net0: virtio=BC:24:11:0A:86:62,bridge=vmbr0,firewall=1,tag=100
```

A tag `100` marca os quadros Ethernet da interface com o identificador VLAN
100 (IEEE 802.1Q). Para essa rede funcionar, toda a cadeia precisa transportar
e configurar a VLAN: bridge VLAN-aware no Proxmox, uplink e switch permitindo
a VLAN, além de uma interface VLAN e DHCP correspondentes no MikroTik.

A configuração do MikroTik mostrou que:

- o DHCP estava associado à bridge da rede principal;
- não havia interface VLAN 100 nem servidor DHCP nessa VLAN;
- a rede configurada era `192.168.88.0/24`.

Assim, embora o Proxmox observasse os pedidos DHCP, não havia um serviço DHCP
configurado na VLAN 100 para entregar um lease à VM.

## Correção

Como a topologia existente utiliza a LAN principal sem segmentação por VLAN, a
tag `100` foi removida da interface da VM. A interface permaneceu conectada à
`vmbr0`, usando DHCP na rede `192.168.88.0/24`.

Após essa alteração:

1. O MikroTik entregou à VM o endereço `192.168.88.253`.
2. O acesso SSH passou a funcionar com o usuário cloud-init `antlss` e a chave
   pública configurada.
3. O QEMU Guest Agent foi instalado no Debian e passou a responder.

## Resultado

A VM Debian ficou acessível pela rede principal do homelab, sem tag VLAN:

- DHCP fornecido pelo MikroTik;
- endereço observado: `192.168.88.253`;
- acesso SSH funcional;
- QEMU Guest Agent disponível após sua instalação.

## Quando usar a VLAN 100

A tag `100` só deve ser habilitada quando a VLAN estiver configurada de ponta a
ponta, incluindo:

1. VLAN 100 e DHCP configurados no MikroTik, com gateway e pool próprios;
2. VLAN 100 permitida no switch e no uplink físico do Proxmox;
3. bridge do Proxmox configurada para VLAN-aware e para transportar a VLAN;
4. interface da VM conectada à bridge com a tag correspondente.

Sem essa configuração completa, mantenha a interface da VM sem tag na rede
principal.

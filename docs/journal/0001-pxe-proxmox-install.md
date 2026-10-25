# 0001 — Instalação do Proxmox VE via PXE (sem pendrive)

**Status:** Concluído

## Objetivo

Instalar o Proxmox VE no mini PC de DevOps inteiramente pela rede, sem usar pendrive físico, para que o cenário possa ser reprovisionado ou expandido no futuro direto do PC principal.

## O que foi feito

1. Recuperação de acesso ao MikroTik (reset de fábrica) após perda de SSH e WebFig.
2. Configuração de TFTP + opção de DHCP (`boot-file-name`) no MikroTik para servir o bootstrap de rede.
3. Uso do netboot.xyz como menu de boot de rede, com chainload manual (via shell do iPXE) para um script próprio.
4. Preparo do instalador automatizado do Proxmox com `proxmox-auto-install-assistant`, rodado dentro de um container Debian (a ferramenta não roda nativa no Fedora/Nobara).
5. Arquivo de resposta (`answer.toml`) com LVM-thin — não ZFS, por causa da RAM atual de 8GB — e filtro por número de série de disco, garantindo que só o NVMe fosse o alvo da instalação, com o SATA preservado intocado para virar storage de backup depois.
6. Instalação concluída com sucesso via rede, sem interação manual após o chainload inicial.

## Dificuldades encontradas e como superamos

| Problema | Causa | Solução |
|---|---|---|
| Perda total de acesso ao MikroTik (SSH e WebFig bloqueados) | Configuração anterior fechou o próprio acesso de gerência | Reset físico de fábrica (botão + observação do LED piscando) |
| `Error: Source file ".../proxmox-ve_9*.iso" does not exist` | Coringa (`*`) não expande no host contra um path que só existe dentro do container montado (`/work`) | Usar o nome exato do arquivo, sem wildcard |
| Combinação `--fetch-from http` + `--answer-file` inconsistente | `--fetch-from http` espera `--url`, não `--answer-file`; esse modo também exige que o servidor aceite requisição POST, o que um `python -m http.server` simples não faz | Trocar para `--fetch-from iso` + `--answer-file`, que embute a resposta direto na imagem preparada |
| `Error: '--output' must point to an existing directory` | A flag `--pxe` não cria a pasta de destino sozinha | `mkdir -p` antes de rodar |
| Teclado USB totalmente sem resposta dentro do menu do netboot.xyz, mas funcionando normalmente na BIOS | Builds netboot.xyz 3.x incluem drivers de rede USB por padrão, que desconectam o driver de teclado USB em firmwares UEFI baseados em AMI (comum em placas Lenovo) — problema catalogado, não específico deste setup | Trocar o binário servido via TFTP/DHCP para `netboot.xyz-legacy.efi`, que omite esses drivers |
| Risco de formatar o disco errado (NVMe vs. SATA) | Nomes posicionais de dispositivo (`sda`, `nvme0n1`) podem variar entre boots e não são garantia de qual disco físico é qual | Filtrar por característica física fixa do disco (`filter.ID_SERIAL`) em vez de nome de dispositivo |

## Comandos e arquivos principais

**MikroTik (RouterOS):**
```
/tool fetch url="https://boot.netboot.xyz/ipxe/netboot.xyz-legacy.efi"
/ip tftp add ip-addresses=192.168.88.0/24 req-filename=netboot.xyz-legacy.efi real-filename=netboot.xyz-legacy.efi allow=yes read-only=yes
/ip dhcp-server network set 0 next-server=192.168.88.1 boot-file-name=netboot.xyz-legacy.efi
```

**`answer.toml` — seção de disco:**
```toml
[disk-setup]
filesystem = "ext4"
filter.ID_SERIAL_SHORT = "*2K4629189BTG*"
```

**Preparo do instalador (dentro do container Debian):**
```bash
proxmox-auto-install-assistant prepare-iso /work/proxmox-ve_9.2-1.iso \
  --fetch-from iso \
  --answer-file /work/answer.toml \
  --pxe --pxe-loader ipxe \
  --output /work/pxe-output/
```

**Chainload no mini PC (shell do iPXE, via Ctrl+B):**
```
chain http://<ip-do-pc-principal>:8000/boot.ipxe
```

## Referências

- [Proxmox VE — Automated Installation (wiki oficial)](https://pve.proxmox.com/wiki/Automated_Installation)
- [netboot.xyz — Troubleshooting (problema de teclado USB)](https://netboot.xyz/docs/getting-started/troubleshooting/)

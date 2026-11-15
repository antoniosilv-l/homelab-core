#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
  if ! command -v bash >/dev/null 2>&1; then
    printf 'Erro: este script precisa do Bash, mas bash não foi encontrado.\n' >&2
    exit 1
  fi
  exec bash "$0" "$@"
fi

set -Eeuo pipefail
export LC_ALL=C.UTF-8

PROGRAM=${0##*/}
ROLE=''
NAME=''
REALM='pve'
COMMENT=''
ACL_PATH=''
GROUP_NAME=''
TOKEN_NAME=''
PRIVSEP=''
EXPIRE=''
PASSWORD_FILE=''
OUTPUT_FILE=''
PASSWORD_VALUE=''
DRY_RUN=0
ASSUME_YES=0
REALM_SET=0
PVE_MAJOR=''
USER_ID=''
GROUP_ID=''
PVE_ROLE=''
EFFECTIVE_PATH=''
TOKEN_ID=''
PVE_USER_CFG=/etc/pve/user.cfg
declare -a RESET_USERS=() RESET_TOKENS=() RESET_GROUPS=() RESET_ROLES=() RESET_ACLS=()
declare -A RESET_ROOT_GROUPS=() RESET_KEEP_ROLES=()

usage() {
  cat <<EOF
Uso:
  $PROGRAM create --role ROLE --name NAME [opções]
  $PROGRAM delete --role ROLE --name NAME [--group GROUP] [opções]
  $PROGRAM show --role ROLE --name NAME [--group GROUP] [opções]
  $PROGRAM reset [--dry-run]
  $PROGRAM list-roles

Roles:
  terraform-api | ansible-api | usuario-comum | auditoria

Opções:
  --role ROLE              Perfil de acesso (obrigatório em create/delete/show)
  --name NAME              Nome de usuário sem realm (obrigatório)
  --realm REALM            pve ou pam (padrão: pve)
  --comment TEXT           Comentário do usuário/grupo/token
  --group NAME             Grupo; criado se não existir (padrão: grp-ROLE)
  --path PATH              Caminho ACL (substitui o padrão do perfil)
  --token-name NAME        Nome do token (padrão: mesmo nome do usuário)
  --privsep 0|1            Separação de privilégios do token
  --expire DATE|EPOCH       Expiração do token; padrão: um ano
  --password-file FILE     Senha de usuario-comum; use - para ler uma linha de stdin
  --output FILE            Arquivo novo, modo 0600, para o segredo de um token novo
  --dry-run                Exibe o plano sem modificar o Proxmox
  --yes                    Não solicita confirmação
  reset                    Remove identidades IAM do PVE, exceto root
  -h, --help               Exibe esta ajuda

delete remove o usuário e todos os seus tokens. Roles customizadas são
compartilhadas e não são removidas. reset remove usuários e tokens não-root,
grupos sem root, ACLs correspondentes e roles customizadas não usadas por root.
Contas PAM/Linux e arquivos do host não são removidos.
EOF
}

die() {
  printf 'Erro: %s\n' "$*" >&2
  exit 1
}

trim() {
  local value=$1
  value=${value#"${value%%[![:space:]]*}"}
  value=${value%"${value##*[![:space:]]}"}
  printf '%s' "$value"
}

role_privileges() {
  case $1 in
    terraform-api)
      if [[ $PVE_MAJOR == 9 ]]; then
        printf '%s' 'Datastore.Audit,Datastore.AllocateSpace,Datastore.AllocateTemplate,SDN.Use,Sys.AccessNetwork,Sys.Audit,Sys.Console,VM.Allocate,VM.Clone,VM.Config.CDROM,VM.Config.CPU,VM.Config.Cloudinit,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.GuestAgent.Audit,VM.PowerMgmt'
      else
        printf '%s' 'Datastore.Audit,Datastore.AllocateSpace,Datastore.AllocateTemplate,SDN.Use,Sys.AccessNetwork,Sys.Audit,Sys.Console,VM.Allocate,VM.Clone,VM.Config.CDROM,VM.Config.CPU,VM.Config.Cloudinit,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Monitor,VM.PowerMgmt'
      fi
      ;;
    ansible-api)
      printf '%s' 'Datastore.Audit,Sys.Audit,VM.Audit,VM.PowerMgmt'
      ;;
    *)
      return 1
      ;;
  esac
}

role_id() {
  case $1 in
    terraform-api) printf '%s' 'TerraformAPI' ;;
    ansible-api) printf '%s' 'AnsibleAPI' ;;
    usuario-comum) printf '%s' 'PVEVMUser' ;;
    auditoria) printf '%s' 'PVEAuditor' ;;
    *) return 1 ;;
  esac
}

default_path() {
  case $1 in
    terraform-api|ansible-api|auditoria) printf '/' ;;
    usuario-comum) printf '/pool/%s' "$NAME" ;;
    *) return 1 ;;
  esac
}

default_privsep() {
  case $1 in
    terraform-api|ansible-api) printf '0' ;;
    usuario-comum|auditoria) printf '1' ;;
    *) return 1 ;;
  esac
}

parse_args() {
  local action=${1:-}
  [[ -n $action ]] || {
    usage >&2
    exit 2
  }
  shift
  case $action in
    create|delete|show|reset|list-roles) ;;
    -h|--help) usage; exit 0 ;;
    *) die "comando desconhecido: $action" ;;
  esac

  while (($#)); do
    case $1 in
      --role|--name|--realm|--comment|--group|--path|--token-name|--privsep|--expire|--password-file|--output)
        (($# >= 2)) || die "faltou valor para $1"
        case $1 in
          --role) ROLE=$2 ;;
          --name) NAME=$2 ;;
          --realm) REALM=$2; REALM_SET=1 ;;
          --comment) COMMENT=$2 ;;
          --group) GROUP_NAME=$2 ;;
          --path) ACL_PATH=$2 ;;
          --token-name) TOKEN_NAME=$2 ;;
          --privsep) PRIVSEP=$2 ;;
          --expire) EXPIRE=$2 ;;
          --password-file) PASSWORD_FILE=$2 ;;
          --output) OUTPUT_FILE=$2 ;;
        esac
        shift 2
        ;;
      --dry-run) DRY_RUN=1; shift ;;
      --yes) ASSUME_YES=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "opção desconhecida: $1" ;;
    esac
  done

  [[ $action == list-roles ]] && {
    [[ -z $ROLE$NAME$COMMENT$GROUP_NAME$ACL_PATH$TOKEN_NAME$PRIVSEP$EXPIRE$PASSWORD_FILE$OUTPUT_FILE ]] \
      || die 'list-roles não aceita opções adicionais'
    [[ $DRY_RUN == 0 && $ASSUME_YES == 0 ]] || die 'list-roles não aceita --dry-run/--yes'
    list_roles
    exit 0
  }

  if [[ $action == reset ]]; then
    [[ -z $ROLE$NAME$COMMENT$GROUP_NAME$ACL_PATH$TOKEN_NAME$PRIVSEP$EXPIRE$PASSWORD_FILE$OUTPUT_FILE ]] \
      && [[ $REALM_SET == 0 ]] \
      || die 'reset não aceita opções de usuário'
    [[ $ASSUME_YES == 0 ]] || die 'reset não aceita --yes; a confirmação digitada é obrigatória'
    return
  fi

  [[ -n $ROLE ]] || die '--role é obrigatório'
  [[ -n $NAME ]] || die '--name é obrigatório'
  [[ $ROLE =~ ^(terraform-api|ansible-api|usuario-comum|auditoria)$ ]] \
    || die "role inválida: $ROLE"
  [[ $NAME =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] \
    || die '--name deve começar com letra ou número e conter apenas letras, números, _ e -'
  [[ $REALM == pve || $REALM == pam ]] || die '--realm deve ser pve ou pam'
  USER_ID="$NAME@$REALM"
  GROUP_ID=${GROUP_NAME:-grp-$ROLE}
  [[ $GROUP_ID =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] \
    || die '--group deve começar com letra ou número e conter apenas letras, números, _ e -'
  PVE_ROLE=$(role_id "$ROLE") || die "role inválida: $ROLE"
  EFFECTIVE_PATH=${ACL_PATH:-$(default_path "$ROLE")}
  [[ $EFFECTIVE_PATH =~ ^/[a-zA-Z0-9._/-]*$ && $EFFECTIVE_PATH != *'..'* \
    && $EFFECTIVE_PATH != *//* ]] || die 'caminho ACL inválido'

  if [[ -n $PRIVSEP ]]; then
    [[ $PRIVSEP == 0 || $PRIVSEP == 1 ]] || die '--privsep deve ser 0 ou 1'
  elif [[ $action == create ]]; then
    PRIVSEP=$(default_privsep "$ROLE")
  fi

  if [[ -n $TOKEN_NAME ]]; then
    [[ $TOKEN_NAME =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || die '--token-name inválido'
  elif [[ $action == create ]]; then
    TOKEN_NAME=$NAME
  fi
  [[ -z $TOKEN_NAME ]] || TOKEN_ID="$USER_ID!$TOKEN_NAME"

  if [[ $action == create && -n $TOKEN_NAME && -z $EXPIRE ]]; then
    EXPIRE=$(date -d '+1 year' +%s) || die 'não foi possível calcular a expiração padrão'
  elif [[ -n $EXPIRE ]]; then
    if [[ $EXPIRE != 0 ]]; then
      if [[ $EXPIRE =~ ^[0-9]+$ ]]; then
        ((EXPIRE > $(date +%s))) || die '--expire deve estar no futuro'
      else
        EXPIRE=$(date -d "$EXPIRE" +%s 2>/dev/null) \
          || die '--expire deve ser uma data reconhecida ou epoch em segundos'
        ((EXPIRE > $(date +%s))) || die '--expire deve estar no futuro'
      fi
    fi
  fi

  if [[ -n $PASSWORD_FILE ]]; then
    [[ $action == create && $ROLE == usuario-comum ]] \
      || die '--password-file só pode ser usado em create --role usuario-comum'
    [[ $PASSWORD_FILE == - || -r $PASSWORD_FILE ]] || die 'arquivo de senha não pode ser lido'
  fi
  [[ -z $OUTPUT_FILE || ( $action == create && -n $TOKEN_NAME ) ]] \
    || die '--output requer create com token'
  [[ -z $EXPIRE || ( $action == create && -n $TOKEN_NAME ) ]] \
    || die '--expire requer create com token'
  [[ -z $PRIVSEP || ( $action == create && -n $TOKEN_NAME ) ]] \
    || die '--privsep requer create com token'
  if [[ $action == delete ]]; then
    [[ -z $COMMENT$ACL_PATH$TOKEN_NAME$PASSWORD_FILE$OUTPUT_FILE$EXPIRE$PRIVSEP ]] \
      || die 'delete não aceita path, comment, opções de token ou senha'
    [[ $DRY_RUN == 0 || $ASSUME_YES == 0 ]] || die 'delete não combina --dry-run e --yes'
  elif [[ $action == show ]]; then
    [[ -z $COMMENT$TOKEN_NAME$PASSWORD_FILE$OUTPUT_FILE$EXPIRE$PRIVSEP ]] \
      || die 'show não aceita opções de criação'
    [[ $DRY_RUN == 0 && $ASSUME_YES == 0 ]] || die 'show não aceita --dry-run/--yes'
  fi
  [[ -z $OUTPUT_FILE || ! -e $OUTPUT_FILE ]] || die '--output deve apontar para um arquivo ainda inexistente'
  [[ -z $OUTPUT_FILE || -d ${OUTPUT_FILE%/*} || ${OUTPUT_FILE%/*} == "$OUTPUT_FILE" ]] \
    || die 'diretório de --output não existe'
}

list_roles() {
  local original_major=$PVE_MAJOR terraform_pve8 terraform_pve9 ansible
  PVE_MAJOR=8
  terraform_pve8=$(role_privileges terraform-api)
  PVE_MAJOR=9
  terraform_pve9=$(role_privileges terraform-api)
  ansible=$(role_privileges ansible-api)
  PVE_MAJOR=$original_major

  printf 'terraform-api (TerraformAPI), path padrão /, token privsep=0, expira em 1 ano\n'
  printf '  PVE 8: %s\n' "$terraform_pve8"
  printf '  PVE 9: %s\n' "$terraform_pve9"
  printf 'ansible-api (AnsibleAPI), path padrão /, token privsep=0, expira em 1 ano\n'
  printf '  %s\n' "$ansible"
  printf 'usuario-comum (PVEVMUser), path padrão /pool/<nome>, token privsep=1\n'
  printf '  Role nativa; não inclui permissões de storage para ISO.\n'
  printf 'auditoria (PVEAuditor), path padrão /, token privsep=1\n'
  printf '  Role nativa de somente leitura.\n'
  printf 'Consulte docs/runbooks/proxmox-iam.md antes de aplicar estes privilégios.\n'
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "comando necessário não encontrado: $1"
}

preflight() {
  local command_name version_output
  [[ $EUID == 0 ]] || die 'execute como root no nó Proxmox'
  for command_name in pveum pveversion awk grep date flock logger chmod; do
    require_command "$command_name"
  done
  if [[ $ROLE == usuario-comum && $REALM == pam ]]; then
    require_command getent
    require_command chpasswd
    getent passwd "$NAME" >/dev/null || die "usuário Linux $NAME não existe para o realm pam"
  fi

  version_output=$(pveversion) || die 'pveversion falhou'
  PVE_MAJOR=$(awk -F'[./]' '/pve-manager/ { print $2; exit }' <<<"$version_output")
  [[ $PVE_MAJOR == 8 || $PVE_MAJOR == 9 ]] \
    || die "versão PVE não suportada (esperado 8.x ou 9.x): $version_output"

  if [[ -e /etc/pve/corosync.conf ]]; then
    require_command pvecm
    if ! pvecm status 2>/dev/null | grep -Eq 'Quorate:[[:space:]]+Yes'; then
      die 'cluster sem quorum ou não foi possível verificar o quorum'
    fi
  fi
}

acquire_lock() {
  exec 9>/run/lock/proxmox-iam.lock || die 'não foi possível abrir o lock'
  flock -n 9 || die 'já existe outra execução do script'
}

confirm_changes() {
  local answer
  [[ $ASSUME_YES == 1 ]] && return 0
  [[ -r /dev/tty ]] || die 'confirmação interativa indisponível; use --yes se revisou a operação'
  printf 'Continuar com %s de %s? [s/N] ' "$1" "$USER_ID" >/dev/tty
  IFS= read -r answer </dev/tty
  [[ $answer == s || $answer == S || $answer == sim || $answer == SIM ]] \
    || die 'operação cancelada'
}

confirm_reset() {
  local answer
  [[ -r /dev/tty ]] || die 'reset exige terminal interativo; revise primeiro com --dry-run'
  printf 'Isso removerá identidades IAM não-root, ACLs e roles customizadas não usadas por root. Digite RESET para continuar: ' >/dev/tty
  IFS= read -r answer </dev/tty
  [[ $answer == RESET ]] || die 'reset cancelado'
}

is_root_identity() {
  [[ ${1%@*} == root ]]
}

acl_entries() {
  pveum acl list | awk -F'[|│]' '
    function trim(s) {
      sub(/^[[:space:]]+/, "", s)
      sub(/[[:space:]]+$/, "", s)
      return s
    }
    {
      for (i = 1; i <= NF; i++) {
        header = tolower(trim($i))
        if (header == "path") path_col = i
        else if (header == "type") type_col = i
        else if (header == "ugid" || header == "user/group/token") id_col = i
        else if (header == "role" || header == "roleid") role_col = i
      }
      if (path_col && type_col && id_col && role_col) {
        path = trim($(path_col))
        type = tolower(trim($(type_col)))
        id = trim($(id_col))
        role = trim($(role_col))
        if (path ~ /^\// && (type == "user" || type == "token" || type == "group") && id != "" && role != "")
          printf "%s\t%s\t%s\t%s\n", path, type, id, role
      }
    }
    END { if (!path_col || !type_col || !id_col || !role_col) exit 2 }
  '
}

load_reset_inventory() {
  local kind id members path type identity role token_owner
  [[ -r $PVE_USER_CFG ]] || die "não foi possível ler $PVE_USER_CFG; reset cancelado"
  RESET_USERS=()
  RESET_TOKENS=()
  RESET_GROUPS=()
  RESET_ROLES=()
  RESET_ACLS=()
  RESET_ROOT_GROUPS=()
  RESET_KEEP_ROLES=()

  while IFS=: read -r kind id members _; do
    case $kind in
      user)
        if ! is_root_identity "$id"; then
          RESET_USERS+=("$id")
        fi
        ;;
      token)
        token_owner=${id%%!*}
        if ! is_root_identity "$token_owner"; then
          RESET_TOKENS+=("$id")
        fi
        ;;
      group)
        RESET_GROUPS+=("$id")
        IFS=, read -r -a group_members <<<"$members"
        for identity in "${group_members[@]}"; do
          if is_root_identity "$identity"; then
            RESET_ROOT_GROUPS["$id"]=1
            break
          fi
        done
        ;;
      role) RESET_ROLES+=("$id") ;;
    esac
  done <"$PVE_USER_CFG"

  local acl_output
  acl_output=$(acl_entries) || die 'não foi possível interpretar as ACLs do Proxmox; reset cancelado'
  while IFS=$'\t' read -r path type identity role; do
    [[ -n $path ]] || continue
    case $type in
      user)
        is_root_identity "$identity" && RESET_KEEP_ROLES["$role"]=1 || RESET_ACLS+=("$path"$'\t'"$type"$'\t'"$identity"$'\t'"$role")
        ;;
      token)
        token_owner=${identity%%!*}
        is_root_identity "$token_owner" && RESET_KEEP_ROLES["$role"]=1 || RESET_ACLS+=("$path"$'\t'"$type"$'\t'"$identity"$'\t'"$role")
        ;;
      group)
        if [[ ${RESET_ROOT_GROUPS[$identity]:-0} == 1 ]]; then
          RESET_KEEP_ROLES["$role"]=1
        else
          RESET_ACLS+=("$path"$'\t'"$type"$'\t'"$identity"$'\t'"$role")
        fi
        ;;
    esac
  done <<<"$acl_output"
}

print_reset_plan() {
  local entry path type identity role item
  printf 'Plano de reset (nenhuma conta PAM/Linux ou arquivo do host será removido):\n'
  for item in "${RESET_USERS[@]}"; do printf '  - remover usuário PVE %s\n' "$item"; done
  for item in "${RESET_TOKENS[@]}"; do printf '  - remover token %s\n' "$item"; done
  for item in "${RESET_GROUPS[@]}"; do
    if [[ ${RESET_ROOT_GROUPS[$item]:-0} == 1 ]]; then
      printf '  - preservar grupo %s porque contém root\n' "$item"
    else
      printf '  - remover grupo %s\n' "$item"
    fi
  done
  for entry in "${RESET_ACLS[@]}"; do
    IFS=$'\t' read -r path type identity role <<<"$entry"
    printf '  - remover ACL: %s %s %s (%s)\n' "$path" "$type" "$identity" "$role"
  done
  for item in "${RESET_ROLES[@]}"; do
    if [[ ${RESET_KEEP_ROLES[$item]:-0} == 1 ]]; then
      printf '  - preservar role customizada %s porque é usada por root\n' "$item"
    else
      printf '  - remover role customizada %s\n' "$item"
    fi
  done
}

reset_environment() {
  local entry path type identity role item token_owner
  preflight
  [[ $DRY_RUN == 1 ]] || acquire_lock
  load_reset_inventory
  print_reset_plan
  [[ $DRY_RUN == 1 ]] && return
  [[ $ASSUME_YES == 0 ]] || die 'reset não pode ser executado com --yes'
  confirm_reset
  ROLE=reset
  USER_ID=all-non-root
  audit_log reset-start

  for entry in "${RESET_ACLS[@]}"; do
    IFS=$'\t' read -r path type identity role <<<"$entry"
    case $type in
      user) pveum acl delete "$path" --users "$identity" --roles "$role" ;;
      token) pveum acl delete "$path" --tokens "$identity" --roles "$role" ;;
      group) pveum acl delete "$path" --groups "$identity" --roles "$role" ;;
    esac || die "não foi possível remover ACL de $identity em $path"
  done

  for item in "${RESET_TOKENS[@]}"; do
    token_owner=${item%%!*}
    pveum user token remove "$token_owner" "${item#*!}" \
      || die "não foi possível remover token $item"
  done
  for item in "${RESET_USERS[@]}"; do
    pveum user delete "$item" || die "não foi possível remover usuário PVE $item"
  done
  for item in "${RESET_GROUPS[@]}"; do
    [[ ${RESET_ROOT_GROUPS[$item]:-0} == 1 ]] && continue
    pveum group delete "$item" || die "não foi possível remover grupo $item"
  done
  for item in "${RESET_ROLES[@]}"; do
    [[ ${RESET_KEEP_ROLES[$item]:-0} == 1 ]] && continue
    pveum role delete "$item" || die "não foi possível remover role customizada $item"
  done

  audit_log reset-complete
  printf 'Reset concluído; root foi preservado.\n'
}

table_has_id() {
  local output=$1 id=$2 id_column=$3
  awk -F'[|│]' -v id="$id" -v id_column="$id_column" '
    function trim(s) {
      sub(/^[[:space:]]+/, "", s)
      sub(/[[:space:]]+$/, "", s)
      return s
    }
    {
      for (i = 1; i <= NF; i++)
        if (tolower(trim($i)) == id_column) id_col = i
      if (id_col > 0 && trim($(id_col)) == id) found = 1
    }
    END { if (!id_col) exit 2; exit !found }
  ' <<<"$output"
}

user_exists() {
  local output
  config_has_entity user "$1" && return 0
  output=$(pveum user list) || die 'não foi possível listar usuários'
  table_has_id "$output" "$1" userid || {
    local status=$?
    [[ $status == 1 ]] && return 1
    config_has_entity user "$1"
  }
}

group_exists() {
  local output
  config_has_entity group "$1" && return 0
  output=$(pveum group list) || die 'não foi possível listar grupos'
  table_has_id "$output" "$1" groupid || {
    local status=$?
    [[ $status == 1 ]] && return 1
    config_has_entity group "$1"
  }
}

role_exists() {
  local output
  config_has_entity role "$1" && return 0
  output=$(pveum role list) || die 'não foi possível listar roles'
  table_has_id "$output" "$1" roleid || {
    local status=$?
    [[ $status == 1 ]] && return 1
    config_has_entity role "$1"
  }
}

config_has_entity() {
  local kind=$1 id=$2
  [[ -r $PVE_USER_CFG ]] || return 1
  awk -F: -v kind="$kind" -v id="$id" \
    '$1 == kind && $2 == id { found = 1 } END { exit !found }' \
    "$PVE_USER_CFG"
}

group_is_assigned() {
  local groups status
  if groups=$(user_groups "$1"); then
    :
  else
    status=$?
    [[ $status == 1 ]] && return 1
    die "não foi possível ler os grupos em $PVE_USER_CFG"
  fi
  [[ ,$groups, == *,"$2",* ]]
}

user_groups() {
  [[ -r $PVE_USER_CFG ]] || return 2
  awk -F: -v id="$1" '
    $1 == "group" {
      count = split($3, members, ",")
      for (i = 1; i <= count; i++) {
        if (members[i] == id) {
          printf "%s%s", (found ? "," : ""), $2
          found = 1
          break
        }
      }
    }
    END { print "" }
  ' "$PVE_USER_CFG"
}

group_has_members() {
  [[ -r $PVE_USER_CFG ]] || return 2
  awk -F: -v group="$1" '
    $1 == "group" && $2 == group {
      found_group = 1
      if ($3 != "") has_members = 1
    }
    END {
      if (!found_group) exit 2
      exit !has_members
    }
  ' "$PVE_USER_CFG"
}

role_definition_matches() {
  local role=$1 expected=$2 output
  output=$(pveum role list) || output=''
  if [[ -n $output ]] && awk -F'[|│]' -v role="$role" -v expected="$expected" '
    function trim(s) {
      sub(/^[[:space:]]+/, "", s)
      sub(/[[:space:]]+$/, "", s)
      return s
    }
    trim($2) == role {
      actual = trim($3)
      n_actual = split(actual, actual_items, ",")
      n_expected = split(expected, expected_items, ",")
      if (n_actual != n_expected) exit 1
      for (i = 1; i <= n_actual; i++) {
        gsub(/[[:space:]]/, "", actual_items[i])
        gsub(/[[:space:]]/, "", expected_items[i])
        found = 0
        for (j = 1; j <= n_expected; j++)
          if (actual_items[i] == expected_items[j]) found = 1
        if (!found) exit 1
      }
      found_role = 1
    }
    END { exit !found_role }
  ' <<<"$output"
  then
    return 0
  fi

  [[ -r $PVE_USER_CFG ]] || return 1
  awk -F: -v role="$role" -v expected="$expected" '
    {
      if ($1 != "role" || $2 != role) next
      n_actual = split($3, actual_items, ",")
      n_expected = split(expected, expected_items, ",")
      if (n_actual != n_expected) exit 1
      for (i = 1; i <= n_actual; i++) {
        gsub(/[[:space:]]/, "", actual_items[i])
        gsub(/[[:space:]]/, "", expected_items[i])
        found = 0
        for (j = 1; j <= n_expected; j++)
          if (actual_items[i] == expected_items[j]) found = 1
        if (!found) exit 1
      }
      found_role = 1
    }
    END { exit !found_role }
  ' "$PVE_USER_CFG"
}

validate_privileges() {
  local privileges privilege role_listing
  if ! privileges=$(role_privileges "$ROLE"); then
    role_exists "$PVE_ROLE" || die "role nativa $PVE_ROLE não encontrada"
    return 0
  fi
  role_listing=$(pveum role list) || die 'não foi possível listar roles'
  IFS=, read -r -a privilege_list <<<"$privileges"
  for privilege in "${privilege_list[@]}"; do
    grep -Fq "$privilege" <<<"$role_listing" \
      || die "o nó não reconhece o privilégio $privilege; nenhuma alteração foi feita"
  done
  if role_exists "$PVE_ROLE"; then
    role_definition_matches "$PVE_ROLE" "$privileges" \
      || die "a role existente $PVE_ROLE não corresponde ao catálogo; revise-a manualmente"
  fi
}

identity_acl_entries() {
  local type=$1 identity=$2
  pveum acl list | awk -F'[|│]' -v type="$type" -v identity="$identity" '
    function trim(s) {
      sub(/^[[:space:]]+/, "", s)
      sub(/[[:space:]]+$/, "", s)
      return s
    }
    trim($3) == type && trim($4) == identity {
      path = trim($2)
      role = trim($5)
      key = path SUBSEP role
      if (!seen[key]++) print path "\t" role
    }
  '
}

token_list() {
  if [[ -r $PVE_USER_CFG ]]; then
    awk -F: -v user="$USER_ID" '
      $1 == "token" {
        split($2, identity, "!")
        if (identity[1] == user && identity[2] != "") print identity[2]
      }
    ' "$PVE_USER_CFG"
    return
  fi

  local output
  output=$(pveum user token list "$USER_ID") || return $?
  [[ -n $output ]] || return 0
  if ! grep -Eiq 'tokenid|token[[:space:]_-]*id' <<<"$output"; then
    if grep -Eiq 'no .*token|token.*not found|nenhum.*token' <<<"$output"; then
      return 0
    fi
    printf 'Não foi possível interpretar a saída de pveum user token list.\n' >&2
    return 2
  fi
  awk -F'[|│]' '
    function trim(s) {
      sub(/^[[:space:]]+/, "", s)
      sub(/[[:space:]]+$/, "", s)
      return s
    }
    {
      for (i = 1; i <= NF; i++) if (tolower(trim($i)) == "tokenid") header = 1
      id = trim($2)
      if (header && id ~ /^[a-zA-Z0-9_-]+$/ && tolower(id) != "tokenid") print id
    }
  ' <<<"$output"
}

user_token_exists() {
  local tokens
  if [[ -r $PVE_USER_CFG ]]; then
    config_has_entity token "$TOKEN_ID"
    return $?
  fi
  tokens=$(token_list) || return $?
  grep -Fxq -- "$TOKEN_NAME" <<<"$tokens"
}

token_privsep() {
  if [[ -r $PVE_USER_CFG ]]; then
    awk -F: -v id="$TOKEN_ID" '
      $1 == "token" && $2 == id {
        print $4
        found = 1
      }
      END { if (!found) exit 2 }
    ' "$PVE_USER_CFG"
    return
  fi

  local output
  output=$(pveum user token list "$USER_ID") || return $?
  [[ -n $output ]] || return 2
  awk -F'[|│]' -v id="$TOKEN_NAME" '
    function trim(s) {
      sub(/^[[:space:]]+/, "", s)
      sub(/[[:space:]]+$/, "", s)
      return s
    }
    {
      for (i = 1; i <= NF; i++) {
        header = tolower(trim($i))
        if (header == "privsep" || header == "privilege separation") privsep_col = i
      }
      if (trim($2) == id && privsep_col > 0) {
        value = tolower(trim($privsep_col))
        if (value == "1" || value == "yes") print 1
        else if (value == "0" || value == "no") print 0
        found = 1
      }
    }
    END {
      if (!privsep_col || !found) exit 2
    }
  ' <<<"$output"
}

audit_log() {
  local action=$1
  if ! logger -t proxmox-iam -- "action=$action user=$USER_ID role=$ROLE path=$EFFECTIVE_PATH actor=${SUDO_USER:-root}"; then
    printf 'Aviso: não foi possível registrar a ação no syslog.\n' >&2
  fi
}

extract_token_secret() {
  awk -F'[|│]' '
    function trim(s) {
      sub(/^[[:space:]]+/, "", s)
      sub(/[[:space:]]+$/, "", s)
      return s
    }
    {
      left = trim($2)
      right = trim($3)
      if (left == "value" && right != "") {
        print right
        exit
      }
      if (match($0, /"value"[[:space:]]*:[[:space:]]*"[^"]+"/)) {
        value = substr($0, RSTART, RLENGTH)
        sub(/^.*:[[:space:]]*"/, "", value)
        sub(/"$/, "", value)
        print value
        exit
      }
    }
  '
}

save_token_secret() {
  local secret=$1
  if [[ -n $OUTPUT_FILE ]]; then
    if ! (umask 077; set -o noclobber; printf '%s\n' "$secret" >"$OUTPUT_FILE"); then
      die "token criado, mas não foi possível gravar o segredo em $OUTPUT_FILE; revogue-o manualmente"
    fi
    chmod 600 "$OUTPUT_FILE" || die "token criado, mas não foi possível proteger $OUTPUT_FILE"
    printf 'Segredo salvo em %s (modo 0600). Guarde uma cópia em um cofre.\n' "$OUTPUT_FILE"
  else
    printf 'Segredo do token (exibido uma única vez; guarde-o em um cofre):\n%s\n' "$secret"
  fi
}

read_password() {
  local password=$PASSWORD_VALUE
  if [[ -z $password ]]; then
    die 'senha não foi carregada'
  fi
  if [[ $REALM == pam ]]; then
    if ! printf '%s:%s\n' "$NAME" "$password" | chpasswd; then
      PASSWORD_VALUE=''
      die 'chpasswd falhou; o usuário pode ter sido criado sem senha'
    fi
  elif ! printf '%s\n%s\n' "$password" "$password" | pveum passwd "$USER_ID"; then
    PASSWORD_VALUE=''
    die 'pveum passwd falhou; o usuário pode ter sido criado sem senha'
  fi
  PASSWORD_VALUE=''
}

load_password() {
  if [[ $PASSWORD_FILE == - ]]; then
    IFS= read -r PASSWORD_VALUE || die 'não foi possível ler a senha de stdin'
  else
    IFS= read -r PASSWORD_VALUE <"$PASSWORD_FILE" || [[ -n ${PASSWORD_VALUE:-} ]] \
      || die 'arquivo de senha vazio ou ilegível'
  fi
  [[ -n $PASSWORD_VALUE ]] || die 'senha vazia não é permitida'
}

ensure_custom_role() {
  local privileges output
  privileges=$(role_privileges "$ROLE") || return 0
  if role_exists "$PVE_ROLE"; then
    printf 'Role %s já existe e corresponde ao catálogo.\n' "$PVE_ROLE"
  else
    if output=$(pveum role add "$PVE_ROLE" -privs "$privileges" 2>&1); then
      printf 'Role %s criada.\n' "$PVE_ROLE"
    elif role_exists "$PVE_ROLE"; then
      role_definition_matches "$PVE_ROLE" "$privileges" \
        || die "a role existente $PVE_ROLE não corresponde ao catálogo; revise-a manualmente"
      printf 'Role %s já existe; será reutilizada.\n' "$PVE_ROLE"
    else
      printf '%s\n' "$output" >&2
      die "não foi possível criar a role $PVE_ROLE"
    fi
  fi
}

create_user() {
  local was_created=0 token_output='' token_secret='' token_exists=0 existing_privsep role_state status
  local group_state
  local current_groups updated_groups group
  local command_output
  local -a token_options=()
  [[ -n $COMMENT ]] || COMMENT="Gerenciado pelo $PROGRAM: $ROLE"
  preflight
  [[ $DRY_RUN == 1 ]] || acquire_lock
  if [[ $DRY_RUN == 0 && $ROLE == usuario-comum && -z $PASSWORD_FILE ]] \
    && ! user_exists "$USER_ID"; then
    die 'para usuario-comum novo, informe --password-file FILE ou --password-file -'
  fi
  validate_privileges
  if [[ -n $OUTPUT_FILE && -e $OUTPUT_FILE ]]; then
    die '--output passou a existir antes da criação do token'
  fi

  if [[ -n $TOKEN_NAME ]] && user_exists "$USER_ID"; then
    if user_token_exists; then
      token_exists=1
    else
      status=$?
      [[ $status == 1 ]] || die "não foi possível listar tokens de $USER_ID"
    fi
  fi
  if ((token_exists)); then
    existing_privsep=$(token_privsep) \
      || die "não foi possível verificar privsep do token existente $TOKEN_ID"
    [[ $existing_privsep == "$PRIVSEP" ]] \
      || die "privsep do token existente $TOKEN_ID não corresponde a --privsep $PRIVSEP"
  fi
  [[ -z $OUTPUT_FILE || $token_exists == 0 ]] \
    || die 'token já existe; seu segredo não pode ser recuperado para --output'

  if [[ $DRY_RUN == 1 ]]; then
    if role_exists "$PVE_ROLE"; then
      role_state=' (já existe)'
    else
      role_state=' (criar)'
    fi
    if group_exists "$GROUP_ID"; then
      group_state=' (reutilizar)'
    else
      group_state=' (criar)'
    fi
    printf 'Plano (nenhuma alteração será feita):\n'
    printf '  - garantir role %s%s\n' "$PVE_ROLE" "$role_state"
    printf '  - garantir grupo %s%s\n' "$GROUP_ID" "$group_state"
    printf '  - garantir usuário %s\n' "$USER_ID"
    printf '  - aplicar ACL do grupo em %s como %s\n' "$EFFECTIVE_PATH" "$PVE_ROLE"
    printf '  - %s token %s (privsep=%s, expiração=%s)\n' \
      "$(if ((token_exists)); then printf 'manter'; else printf 'criar'; fi)" \
      "$TOKEN_ID" "$PRIVSEP" "${EXPIRE:-0}"
    [[ $PRIVSEP == 1 && -n $TOKEN_NAME ]] && printf '  - aplicar ACL separada ao token\n'
    return
  fi

  confirm_changes create
  if [[ $ROLE == usuario-comum && -n $PASSWORD_FILE ]] && ! user_exists "$USER_ID"; then
    load_password
  fi
  audit_log create-start
  ensure_custom_role
  if ! group_exists "$GROUP_ID"; then
    if command_output=$(pveum group add "$GROUP_ID" --comment "$COMMENT" 2>&1); then
      printf 'Grupo %s criado.\n' "$GROUP_ID"
    elif group_exists "$GROUP_ID"; then
      printf 'Grupo %s já existe; será reutilizado.\n' "$GROUP_ID"
    else
      printf '%s\n' "$command_output" >&2
      die "não foi possível criar o grupo $GROUP_ID"
    fi
  else
    printf 'Grupo %s já existe; será reutilizado.\n' "$GROUP_ID"
  fi
  if ! user_exists "$USER_ID"; then
    if command_output=$(pveum user add "$USER_ID" --comment "$COMMENT" 2>&1); then
      was_created=1
      printf 'Usuário %s criado.\n' "$USER_ID"
      if [[ $ROLE == usuario-comum ]]; then
        read_password
      fi
    elif user_exists "$USER_ID"; then
      printf 'Usuário %s já existe; será reutilizado.\n' "$USER_ID"
    else
      printf '%s\n' "$command_output" >&2
      die "não foi possível criar o usuário $USER_ID"
    fi
  elif [[ -n $PASSWORD_FILE ]]; then
    printf 'Usuário já existe; senha não alterada.\n'
  fi
  if ! group_is_assigned "$USER_ID" "$GROUP_ID"; then
    current_groups=$(user_groups "$USER_ID") \
      || die "não foi possível ler os grupos atuais de $USER_ID"
    updated_groups=${current_groups:+$current_groups,}$GROUP_ID
    pveum user modify "$USER_ID" --groups "$updated_groups"
    printf 'Usuário adicionado ao grupo %s.\n' "$GROUP_ID"
  fi
  pveum acl modify "$EFFECTIVE_PATH" --groups "$GROUP_ID" --roles "$PVE_ROLE"
  printf 'ACL do grupo aplicada em %s.\n' "$EFFECTIVE_PATH"

  if [[ -n $TOKEN_NAME ]]; then
    if [[ $token_exists == 1 ]]; then
      printf 'Token %s já existe; segredo não pode ser recuperado nem recriado.\n' "$TOKEN_ID"
    else
      token_options=(--privsep "$PRIVSEP" --comment "$COMMENT")
      [[ -z $EXPIRE || $EXPIRE == 0 ]] || token_options+=(--expire "$EXPIRE")
      if token_output=$(pveum user token add "$USER_ID" "$TOKEN_NAME" \
        "${token_options[@]}" --output-format json 2>&1); then
        token_secret=$(extract_token_secret <<<"$token_output")
        token_output=''
        [[ -n $token_secret ]] \
          || die "token criado, mas o segredo retornado pelo pveum não pôde ser extraído; revogue $TOKEN_ID e crie-o novamente"
        save_token_secret "$token_secret"
        token_secret=''
      elif user_token_exists; then
        token_output=''
        [[ -z $OUTPUT_FILE ]] \
          || die "token $TOKEN_ID já existe e seu segredo não pode ser recuperado para --output"
        existing_privsep=$(token_privsep) \
          || die "não foi possível verificar privsep do token existente $TOKEN_ID"
        [[ $existing_privsep == "$PRIVSEP" ]] \
          || die "privsep do token existente $TOKEN_ID não corresponde a --privsep $PRIVSEP"
        token_exists=1
        printf 'Token %s já existe; será reutilizado sem alterar expiração nem segredo.\n' "$TOKEN_ID"
      else
        token_output=''
        die "pveum falhou ao criar $TOKEN_ID; saída omitida para proteger o segredo. Verifique o estado antes de tentar novamente"
      fi
    fi
    if [[ $PRIVSEP == 1 ]]; then
      pveum acl modify "$EFFECTIVE_PATH" --tokens "$TOKEN_ID" --roles "$PVE_ROLE" \
        || die "não foi possível aplicar a ACL separada do token $TOKEN_ID"
      printf 'ACL separada aplicada ao token.\n'
    fi
  fi

  audit_log create-complete
  ((was_created == 0)) || printf 'Usuário criado; guarde os segredos fora do nó Proxmox.\n'
}

delete_user() {
  local token token_identity tokens entries path role status
  preflight
  [[ $DRY_RUN == 1 ]] || acquire_lock
  if [[ $DRY_RUN == 1 ]]; then
    printf 'Plano (nenhuma alteração será feita):\n'
    printf '  - remover todos os tokens de %s\n' "$USER_ID"
    printf '  - remover %s do grupo %s e excluir o usuário\n' "$USER_ID" "$GROUP_ID"
    printf '  - remover todas as ACLs do grupo somente se não houver outros membros\n'
    return
  fi
  confirm_changes delete
  audit_log delete-start

  if user_exists "$USER_ID"; then
    tokens=$(token_list) || die "não foi possível listar tokens de $USER_ID"
    while IFS= read -r token; do
      [[ -n $token ]] || continue
      token_identity="$USER_ID!$token"
      entries=$(identity_acl_entries token "$token_identity") \
        || die "não foi possível listar ACLs do token $token_identity"
      while IFS=$'\t' read -r path role; do
        [[ -n $path ]] || continue
        pveum acl delete "$path" --tokens "$token_identity" --roles "$role"
      done <<<"$entries"
      pveum user token remove "$USER_ID" "$token"
      printf 'Token %s!%s removido.\n' "$USER_ID" "$token"
    done <<<"$tokens"

    pveum user delete "$USER_ID"
    printf 'Usuário %s removido.\n' "$USER_ID"
  else
    printf 'Usuário %s não existe; verificando limpeza do grupo.\n' "$USER_ID"
  fi

  if [[ -n $GROUP_NAME ]]; then
    printf 'Grupo personalizado %s preservado; não foi removido.\n' "$GROUP_ID"
  elif group_exists "$GROUP_ID"; then
    if group_has_members "$GROUP_ID"; then
      printf 'Grupo %s mantido porque ainda possui membros.\n' "$GROUP_ID"
    else
      status=$?
      [[ $status == 1 ]] || die 'não foi possível verificar membros do grupo; limpeza cancelada'
      entries=$(identity_acl_entries group "$GROUP_ID") \
        || die "não foi possível listar ACLs do grupo $GROUP_ID"
      while IFS=$'\t' read -r path role; do
        [[ -n $path ]] || continue
        pveum acl delete "$path" --groups "$GROUP_ID" --roles "$role"
      done <<<"$entries"
      pveum group delete "$GROUP_ID"
      printf 'Grupo vazio %s e sua ACL removidos.\n' "$GROUP_ID"
    fi
  fi
  audit_log delete-complete
}

show_user() {
  local users acls found=0
  preflight
  users=$(pveum user list) || die 'não foi possível listar usuários'
  if table_has_id "$users" "$USER_ID" userid || config_has_entity user "$USER_ID"; then
    printf 'Usuário:\n'
    awk -F'[|│]' -v id="$USER_ID" '
      function trim(s) {
        sub(/^[[:space:]]+/, "", s)
        sub(/[[:space:]]+$/, "", s)
        return s
      }
      trim($2) == id { print; found = 1 }
      END { if (!found) exit 1 }
    ' <<<"$users"
    found=1
    printf 'Tokens:\n'
    pveum user token list "$USER_ID"
  else
    printf 'Usuário %s não encontrado.\n' "$USER_ID"
  fi
  if group_exists "$GROUP_ID"; then
    printf 'Grupo: %s\n' "$GROUP_ID"
  fi
  acls=$(pveum acl list) || die 'não foi possível listar ACLs'
  printf 'ACLs relacionadas:\n'
  while IFS= read -r line; do
    line=${line//│/|}
    if [[ $line == *"| $EFFECTIVE_PATH "* ]] \
      && [[ $line == *"| group | $GROUP_ID "* || $line == *"| token | $USER_ID!"* ]]; then
      printf '%s\n' "$line"
      found=1
    fi
  done <<<"$acls"
  ((found == 1)) || return 1
}

main() {
  local action=${1:-}
  parse_args "$@"
  case $action in
    create) create_user ;;
    delete) delete_user ;;
    show) show_user ;;
    reset) reset_environment ;;
    list-roles) ;;
  esac
}

main "$@"

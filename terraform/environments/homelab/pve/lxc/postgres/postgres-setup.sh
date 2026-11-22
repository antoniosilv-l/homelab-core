#!/usr/bin/env bash
set -euo pipefail

: "${POSTGRES_PASSWORD_FILE:?POSTGRES_PASSWORD_FILE is required}"
: "${POSTGRES_ALLOWED_CIDR:?POSTGRES_ALLOWED_CIDR is required}"

postgres_password_file="/var/lib/postgresql/.postgres-password"
cleanup() {
  rm -f "$POSTGRES_PASSWORD_FILE" "$postgres_password_file"
}
trap cleanup EXIT

password="$(cat "$POSTGRES_PASSWORD_FILE")"
if [[ ! "$password" =~ ^[0-9a-fA-F]{64}$ ]]; then
  echo "POSTGRES_PASSWORD_FILE must contain a 64-character hexadecimal password." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y postgresql

pg_version="$(find /etc/postgresql -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V | tail -n 1)"
pg_config_dir="/etc/postgresql/${pg_version}/main"

set_postgres_config() {
  local key="$1"
  local value="$2"
  local config_file="$3"

  if grep -Eq "^[[:space:]]*#?[[:space:]]*${key}[[:space:]]*=" "$config_file"; then
    sed -i -E "s|^[[:space:]]*#?[[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|" "$config_file"
  else
    printf '%s = %s\n' "$key" "$value" >>"$config_file"
  fi
}

set_postgres_config "listen_addresses" "'*'" "${pg_config_dir}/postgresql.conf"
set_postgres_config "password_encryption" "'scram-sha-256'" "${pg_config_dir}/postgresql.conf"

pg_hba_file="${pg_config_dir}/pg_hba.conf"
sed -i '/^# BEGIN homelab-managed-postgres-access$/,/^# END homelab-managed-postgres-access$/d' "$pg_hba_file"
{
  printf '%s\n' "# BEGIN homelab-managed-postgres-access"
  printf 'host all postgres %s scram-sha-256\n' "$POSTGRES_ALLOWED_CIDR"
  printf '%s\n' "# END homelab-managed-postgres-access"
} >>"$pg_hba_file"

systemctl enable postgresql
systemctl restart postgresql

install -o postgres -g postgres -m 600 "$POSTGRES_PASSWORD_FILE" "$postgres_password_file"
# shellcheck disable=SC2016
runuser -u postgres -- env POSTGRES_PASSWORD_FILE="$postgres_password_file" /bin/bash -c \
  'export POSTGRES_PASSWORD="$(cat "$POSTGRES_PASSWORD_FILE")"; exec psql --set=ON_ERROR_STOP=1' <<'SQL'
\getenv postgres_password POSTGRES_PASSWORD
ALTER ROLE postgres WITH PASSWORD :'postgres_password';
SQL

pg_isready --host=127.0.0.1

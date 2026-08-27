#!/usr/bin/env bash
set -euo pipefail

PG_VERSION=18
STANZA=main
PG_CONF_DIR="/etc/postgresql/${PG_VERSION}/main"
PG_SERVICE="postgresql@${PG_VERSION}-main"

if ! command -v pgbackrest >/dev/null 2>&1; then
  echo "pgbackrest is not installed; aborting." >&2
  exit 1
fi

if [[ ! -d "$PG_CONF_DIR" ]]; then
  echo "${PG_CONF_DIR} not found; aborting." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sudo mkdir -p /var/lib/pgbackrest /var/log/pgbackrest
sudo chmod 750 /var/lib/pgbackrest /var/log/pgbackrest
sudo chown postgres:postgres /var/lib/pgbackrest /var/log/pgbackrest

if [[ -f /etc/pgbackrest.conf ]]; then
  sudo cp /etc/pgbackrest.conf /etc/pgbackrest.conf.bak
fi

sudo cp "$SCRIPT_DIR/pgbackrest.conf" /etc/pgbackrest.conf

sudo mkdir -p "${PG_CONF_DIR}/conf.d"
sudo cp "$SCRIPT_DIR/postgresql.conf" "${PG_CONF_DIR}/conf.d/99-pgbackrest.conf"

sudo systemctl restart "$PG_SERVICE"

if ! sudo -u postgres pgbackrest --stanza="$STANZA" info &>/dev/null; then
  sudo -u postgres pgbackrest --stanza="$STANZA" stanza-create
fi

sudo -u postgres pgbackrest --stanza="$STANZA" check
sudo -u postgres pgbackrest --stanza="$STANZA" backup --type=full

sudo cp "$SCRIPT_DIR"/systemd/pgbackrest-full.service /etc/systemd/system/
sudo cp "$SCRIPT_DIR"/systemd/pgbackrest-full.timer /etc/systemd/system/
sudo cp "$SCRIPT_DIR"/systemd/pgbackrest-incr.service /etc/systemd/system/
sudo cp "$SCRIPT_DIR"/systemd/pgbackrest-incr.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now pgbackrest-full.timer pgbackrest-incr.timer

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

if [[ ! -f /etc/pgbackrest.conf ]]; then
  echo "/etc/pgbackrest.conf not found; run bootstrap.sh first." >&2
  exit 1
fi

sudo systemctl restart "$PG_SERVICE"

if ! sudo -u postgres pgbackrest --stanza="$STANZA" info &>/dev/null; then
  sudo -u postgres pgbackrest --stanza="$STANZA" stanza-create
fi

sudo -u postgres pgbackrest --stanza="$STANZA" check
sudo -u postgres pgbackrest --stanza="$STANZA" --type=full backup

sudo systemctl daemon-reload
sudo systemctl enable --now pgbackrest-full.timer pgbackrest-incr.timer

#!/usr/bin/env bash
set -euo pipefail

if ! command -v pgbouncer >/dev/null 2>&1; then
  echo "pgbouncer is not installed; aborting." >&2
  exit 1
fi


sudo systemctl start pgbouncer
sudo systemctl enable pgbouncer
sudo systemctl status --no-pager --full pgbouncer




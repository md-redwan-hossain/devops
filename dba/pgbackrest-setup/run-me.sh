#!/usr/bin/env bash

sudo mkdir -p /var/lib/pgbackrest
sudo chmod 750 /var/lib/pgbackrest
sudo chown postgres:postgres /var/lib/pgbackrest

sudo -u postgres pgbackrest --stanza=main stanza-create

sudo systemctl restart postgresql@18-main

sudo -u postgres pgbackrest --stanza=main check

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sudo cp "$SCRIPT_DIR"/systemd/pgbackrest-full.service "$SCRIPT_DIR"/systemd/pgbackrest-full.timer \
       "$SCRIPT_DIR"/systemd/pgbackrest-incr.service "$SCRIPT_DIR"/systemd/pgbackrest-incr.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now pgbackrest-full.timer pgbackrest-incr.timer

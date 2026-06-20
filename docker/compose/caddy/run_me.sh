#!/usr/bin/env bash

mkdir -p static_sites
mkdir -p caddy_data
mkdir -p caddy_config

touch Caddyfile

docker network inspect caddy_network >/dev/null 2>&1 || docker network create caddy_network

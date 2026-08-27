#!/usr/bin/env bash

docker network inspect zot_network >/dev/null 2>&1 || docker network create zot_network
docker network inspect app_network >/dev/null 2>&1 || docker network create app_network
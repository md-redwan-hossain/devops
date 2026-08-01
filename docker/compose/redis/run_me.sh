#!/usr/bin/env bash

docker network inspect redis_network >/dev/null 2>&1 || docker network create redis_network
docker network inspect app_network >/dev/null 2>&1 || docker network create app_network

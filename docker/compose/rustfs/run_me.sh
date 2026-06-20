#!/usr/bin/env bash

mkdir -p rustfs_data
mkdir -p rustfs_logs

docker network inspect rustfs_network >/dev/null 2>&1 || docker network create rustfs_network

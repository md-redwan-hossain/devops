#!/usr/bin/env bash

mkdir -p rustfs_data rustfs_logs
chown -R 10001:10001 rustfs_data rustfs_logs

docker network inspect rustfs_network >/dev/null 2>&1 || docker network create rustfs_network
#!/usr/bin/env bash

mkdir -p container_data/gitea_data 
chown 1000:1000 container_data/gitea_data 
mkdir -p container_data/gitea_db
chown 999:999 container_data/gitea_db
mkdir -p container_data/gitea_runner_data
chown 1000:1000 container_data/gitea_runner_data

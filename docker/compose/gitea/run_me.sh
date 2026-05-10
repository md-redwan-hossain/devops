#!/usr/bin/env bash

mkdir -p container_data/gitea_data
sudo chown 1000:1000 container_data/gitea_data
mkdir -p container_data/gitea_db
sudo chown 999:999 container_data/gitea_db
mkdir -p container_data/gitea_runner_data
sudo chown 1000:1000 container_data/gitea_runner_data
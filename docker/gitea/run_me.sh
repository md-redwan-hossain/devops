#!/usr/bin/env bash

mkdir -p container_data/gitea_data 
chown 1000:1000 gitea_data
mkdir container_data/gitea_db -p 
chown 999:999 gitea_db
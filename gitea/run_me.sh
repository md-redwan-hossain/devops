#!/usr/bin/env bash

mkdir -p gitea_data 
chown 1000:1000 gitea_data
mkdir gitea_db -p 
chown 999:999 gitea_db
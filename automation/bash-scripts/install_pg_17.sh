#!/bin/bash

# Prompt for the Ubuntu codename and PostgreSQL version
read -p "Enter the Ubuntu codename (e.g., jammy): " codename
read -p "Enter the PostgreSQL version (e.g., 17): " pg_version

# Check if codename or PostgreSQL version is empty
if [[ -z "$codename" || -z "$pg_version" ]]; then
  echo "Codename and PostgreSQL version cannot be empty. Exiting."
  exit 1
fi

# Determine the system architecture
arch=$(dpkg --print-architecture)

# Print the entry as a friendly message
echo "Adding PostgreSQL repository for Ubuntu $codename with architecture $arch..."

# Add PostgreSQL repository
sudo sh -c "echo 'deb [arch=$arch] http://apt.postgresql.org/pub/repos/apt $codename-pgdg main' > /etc/apt/sources.list.d/pgdg.list"

# Import the PostgreSQL signing key
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg

# Update package lists
sudo apt update

# Install PostgreSQL and contrib package
sudo apt install -y postgresql-$pg_version postgresql-contrib

# Start and enable PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Check the status of PostgreSQL service
sudo systemctl status postgresql

# Add PostgreSQL binary path to .bashrc and source it
echo "PATH=\$PATH:/usr/lib/postgresql/$pg_version/bin" >> ~/.bashrc
source ~/.bashrc

echo "PostgreSQL $pg_version installation and setup completed for Ubuntu $codename."
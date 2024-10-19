#!/bin/bash

# Prompt for the Ubuntu codename
read -p "Enter the Ubuntu codename (e.g., jammy): " codename

# Check if codename is empty
if [[ -z "$codename" ]]; then
  echo "Codename cannot be empty. Exiting."
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
sudo apt install -y postgresql-17 postgresql-contrib

# Start and enable PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Check the status of PostgreSQL service
sudo systemctl status postgresql

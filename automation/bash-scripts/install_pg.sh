#!/bin/bash

# Prompt for the Ubuntu codename and PostgreSQL version
while true; do
  read -p "Enter the Ubuntu codename (e.g., focal, jammy, noble): " codename_input
  codename=$(echo "$codename_input" | tr '[:upper:]' '[:lower:]')
  if [[ "$codename" =~ ^(focal|jammy|noble)$ ]]; then
    break
  else
    echo "Invalid codename. Please enter one of: focal, jammy, noble."
  fi
done

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
sudo systemctl status --no-pager --full postgresql

# Add PostgreSQL bin directory to PATH permanently
if ! grep -q '/usr/lib/postgresql/$pg_version/bin' "$HOME/.bashrc"; then
  echo "" >> "$HOME/.bashrc"
  echo "export PATH=\"/usr/lib/postgresql/$pg_version/bin:\$PATH\"" >> "$HOME/.bashrc"
fi

source ~/.bashrc

echo "PostgreSQL $pg_version installation and setup completed for Ubuntu $codename."

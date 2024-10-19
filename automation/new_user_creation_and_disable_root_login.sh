#!/bin/bash

# Prompt for username and password
read -p "Enter new username: " username
read -sp "Enter password for $username: " password
echo

# Check if username or password is empty
if [[ -z "$username" || -z "$password" ]]; then
  echo "Username or password cannot be empty. Exiting."
  exit 1
fi

# Create a new user and set the password
adduser --disabled-password --gecos "" $username
echo "$username:$password" | chpasswd

# Grant the new user sudo privileges
usermod -aG sudo $username

# Disable root login
sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# Restart the SSH service
systemctl restart sshd

echo "User $username created and root login disabled."

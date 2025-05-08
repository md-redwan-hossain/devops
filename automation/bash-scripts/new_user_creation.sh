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
adduser --disabled-password --gecos "" "$username"
echo "$username:$password" | chpasswd

# Grant the new user sudo privileges
usermod -aG sudo "$username"

# Ask whether to disable root login
read -p "Do you want to disable root SSH login? [y/N]: " disable_root
if [[ "$disable_root" =~ ^[Yy]$ ]]; then
  # Disable root login
  if grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
    sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  else
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config
  fi

  # Restart the SSH service
  systemctl restart sshd
  echo "Root SSH login has been disabled."
else
  echo "Skipping disabling of root SSH login."
fi

echo "User $username created successfully."

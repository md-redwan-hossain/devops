#!/usr/bin/env bash
set -euo pipefail

read -p "Enter new username: " username

# Prompt for password twice (hidden)
read -s -p "Enter password for $username: " password
echo
read -s -p "Confirm password for $username: " password2
echo

# If they don’t match, exit with error
if [[ "$password" != "$password2" ]]; then
  echo "Error: passwords do not match." >&2
  exit 1
fi

# Create the user and set the password
adduser --disabled-password --gecos "" "$username"
echo "$username:$password" | chpasswd

# Grant sudo privileges
usermod -aG sudo "$username"

# Ask whether to disable root SSH login
read -p "Disable root SSH login? [y/N]: " disable_root
if [[ "$disable_root" =~ ^[Yy]$ ]]; then
  if grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
    sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  else
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config
  fi
  echo "Root SSH login disabled."
else
  echo "Root SSH login left unchanged."
fi

# Restart whichever SSH service is active
if systemctl is-active --quiet sshd; then
  systemctl restart sshd
  echo "Restarted sshd.service"
elif systemctl is-active --quiet ssh; then
  systemctl restart ssh
  echo "Restarted ssh.service"
else
  echo "No SSH service (sshd or ssh) is active; skipping restart."
fi


echo "User $username created successfully."
echo "Don't forget to set up SSH keys for the new user!"

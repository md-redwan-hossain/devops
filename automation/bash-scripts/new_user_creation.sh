#!/usr/bin/env bash
set -euo pipefail

# Determine which user’s keys to copy: prefer SUDO_USER when using sudo
source_user="${SUDO_USER:-$USER}"
read -p "Enter new username: " username

# Loop until password and confirmation match
while true; do
  read -s -p "Enter password for $username: " password
  echo
  read -s -p "Confirm password for $username: " password2
  echo
  if [[ "$password" == "$password2" ]]; then
    break
  fi
  echo "Passwords do not match. Please try again." >&2
done

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

# Ask whether to copy the invoker’s authorized_keys to the new user
read -p "Copy SSH keys from '$source_user' to '$username'? [y/N]: " copy_keys
if [[ "$copy_keys" =~ ^[Yy]$ ]]; then
  # Resolve the home directory of the source user
  source_home="$(getent passwd "$source_user" | cut -d: -f6)"
  target_ssh_dir="/home/$username/.ssh"

  # Ensure the target .ssh directory exists
  mkdir -p "$target_ssh_dir"

  # Copy and secure
  cp "$source_home/.ssh/authorized_keys" "$target_ssh_dir/authorized_keys"
  chmod 600 "$target_ssh_dir/authorized_keys"
  chown -R "$username:$username" "$target_ssh_dir"

  echo "Copied SSH keys from '$source_user' to '$username'."
else
  echo "Skipping SSH key copy."
fi

echo "User $username created successfully."

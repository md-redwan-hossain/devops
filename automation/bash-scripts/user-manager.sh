#!/usr/bin/env bash
set -euo pipefail

source_user="${SUDO_USER:-${USER:-$(id -un)}}"
sshd_dropin="/etc/ssh/sshd_config.d/99-root-login.conf"
user_created=0

prompt_password() {
  local password password2
  while true; do
    read -r -s -p "Enter password for $username: " password
    echo
    read -r -s -p "Confirm password for $username: " password2
    echo
    if [[ "$password" == "$password2" ]]; then
      echo "$username:$password" | chpasswd
      echo "Password set for '$username'."
      return
    fi
    echo "Passwords do not match. Please try again." >&2
  done
}

reload_ssh_if_active() {
  if systemctl is-active --quiet sshd; then
    systemctl reload sshd
    echo "Reloaded sshd.service"
  elif systemctl is-active --quiet ssh; then
    systemctl reload ssh
    echo "Reloaded ssh.service"
  else
    echo "No SSH service (sshd or ssh) is active; skipping reload."
  fi
}

current_permit_root_login() {
  if [[ -f "$sshd_dropin" ]]; then
    tr -d '\r' <"$sshd_dropin" | sed -n 's/^PermitRootLogin[[:space:]]\{1,\}\([^[:space:]]*\).*/\1/p' | tail -n1
  fi
}

apply_permit_root_login() {
  local desired="$1"
  local content="PermitRootLogin ${desired}"
  local current=""

  if [[ -f "$sshd_dropin" ]]; then
    current="$(tr -d '\r' <"$sshd_dropin" | sed '/^[[:space:]]*$/d')"
  fi

  if [[ "$current" == "$content" ]]; then
    echo "PermitRootLogin already set to '${desired}'."
    return
  fi

  mkdir -p "$(dirname "$sshd_dropin")"
  printf '%s\n' "$content" >"$sshd_dropin"
  echo "Set PermitRootLogin ${desired} in ${sshd_dropin}."

  if ! sshd -t; then
    echo "sshd config test failed; removing ${sshd_dropin}." >&2
    rm -f "$sshd_dropin"
    exit 1
  fi

  reload_ssh_if_active
}

read -r -p "Enter username: " username
if [[ -z "$username" ]]; then
  echo "Username cannot be empty." >&2
  exit 1
fi

if id "$username" &>/dev/null; then
  echo "User '$username' already exists."
  read -r -p "Change password for '$username'? [y/N]: " change_pass
  if [[ "$change_pass" =~ ^[Yy]$ ]]; then
    prompt_password
  else
    echo "Password left unchanged."
  fi
else
  adduser --disabled-password --gecos "" "$username"
  user_created=1
  prompt_password
fi

usermod -aG sudo "$username"
echo "Ensured '$username' is in the sudo group."

desired_root=""
read -r -p "Disable all root SSH login? [y/N]: " disable_root_ssh
if [[ "$disable_root_ssh" =~ ^[Yy]$ ]]; then
  desired_root="no"
else
  read -r -p "Disable root password login over SSH? [y/N]: " disable_root_password
  if [[ "$disable_root_password" =~ ^[Yy]$ ]]; then
    desired_root="prohibit-password"
  else
    current_root="$(current_permit_root_login)"
    if [[ "$current_root" == "no" || "$current_root" == "prohibit-password" ]]; then
      read -r -p "Re-enable root SSH login? [y/N]: " reenable_root
      if [[ "$reenable_root" =~ ^[Yy]$ ]]; then
        desired_root="yes"
      fi
    fi
  fi
fi

if [[ -n "$desired_root" ]]; then
  apply_permit_root_login "$desired_root"
else
  echo "Root SSH settings left unchanged."
fi

if (( user_created )); then
  source_home="$(getent passwd "$source_user" | cut -d: -f6)"
  src_keys="$source_home/.ssh/authorized_keys"

  if [[ -f "$src_keys" ]]; then
    read -r -p "Copy SSH keys from '$source_user' to '$username'? [y/N]: " copy_keys
    if [[ "$copy_keys" =~ ^[Yy]$ ]]; then
      target_ssh_dir="/home/$username/.ssh"
      mkdir -p "$target_ssh_dir"
      cp "$src_keys" "$target_ssh_dir/authorized_keys"
      chmod 700 "$target_ssh_dir"
      chmod 600 "$target_ssh_dir/authorized_keys"
      chown -R "$username:$username" "$target_ssh_dir"
      echo "Copied SSH keys from '$source_user' to '$username'."
    fi
  fi
  echo "User '$username' created successfully."
else
  echo "User '$username' updated successfully."
fi

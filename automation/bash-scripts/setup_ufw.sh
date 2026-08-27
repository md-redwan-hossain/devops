#!/usr/bin/env bash
set -euo pipefail

PUBLIC_NIC="${PUBLIC_NIC:-eth0}"

if [[ -z "${PORT:-}" ]]; then
  while true; do
    read -r -p "TCP port to manage with UFW: " PORT
    if [[ "$PORT" =~ ^[0-9]+$ ]] && (( PORT >= 1 && PORT <= 65535 )); then
      break
    fi
    echo "Invalid port. Enter a number between 1 and 65535." >&2
  done
fi

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  echo "Invalid port: $PORT" >&2
  exit 1
fi

ufw_rule_exists() {
  sudo ufw show added 2>/dev/null | grep -qF "$1"
}

ufw_allow_once() {
  local rule="ufw allow $*"
  if ufw_rule_exists "$rule"; then
    echo "Already present: $rule"
  else
    sudo ufw allow "$@"
    echo "Added: $rule"
  fi
}

ufw_deny_once() {
  local rule="ufw deny $*"
  if ufw_rule_exists "$rule"; then
    echo "Already present: $rule"
  else
    sudo ufw deny "$@"
    echo "Added: $rule"
  fi
}

remove_legacy_broad_allow() {
  local port="$1"
  for spec in "allow ${port}/tcp" "allow ${port}"; do
    if ufw_rule_exists "ufw ${spec}"; then
      sudo ufw --force delete "$spec"
      echo "Removed legacy broad rule: ufw ${spec}"
    fi
  done
}

echo "Using port: $PORT"

sudo ufw --force enable
remove_legacy_broad_allow "$PORT"

ufw_allow_once OpenSSH
ufw_allow_once http
ufw_allow_once https

ufw_allow_once in on tailscale0 to any port "$PORT" proto tcp
ufw_allow_once in on lo       to any port "$PORT" proto tcp
ufw_allow_once from 172.16.0.0/12 to any port "$PORT" proto tcp

ufw_deny_once in on "$PUBLIC_NIC" to any port "$PORT" proto tcp
ufw_deny_once "${PORT}"/tcp

sudo ufw reload
sudo ufw status verbose
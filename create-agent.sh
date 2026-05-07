#!/bin/bash
#
# create a new user for an AI agent
# Should be idempotent - fix files if not correct

# preamble

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Error: need 1 argument (agent name)"
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

# Functions

is_password_locked() {
    local user=$1
    local hash
    hash=$(getent shadow $user | cut -d: -f2)

    case "$hash" in
        ""|"!"|"!!"|"*"|"!"*|"*"*) return 0;;
        *) return 1 ;;
    esac
}

ensure_group_membership() {
    local user=$1
    local group=$2

    if ! id -nG "$user" | tr ' ' '\n' | grep -qx "$group"; then
        echo "adding $user to $group"
        usermod -aG agents "$user"
    fi
}

ensure_permissions() {
    local path=$1 want_owner=$2 want_group=$3 want_mode=$4
    local owner group mode
    read -r owner group mode < <(stat -c '%U %G %a' "$path")
    [ "$owner" = "$want_owner" ] || chown "$want_owner" "$path"
    [ "$group" = "$want_group" ] || chgrp "$want_group" "$path"
    [ "$mode" = "$want_mode" ] || chmod "$want_mode" "$path"
}

# Script

if ! id "$AGENT" &>/dev/null; then
    echo "New user: $AGENT"
    adduser --disabled-password --gecos "" --shell /bin/bash "$AGENT"
else
    echo "User exists: $AGENT"
fi

if ! is_password_locked "$AGENT"; then
    echo "Locking password for $AGENT"
    passwd -l "$AGENT"
fi

if ! getent group agents > /dev/null; then
    echo "Creating 'agents' group"
    groupadd agents
fi
ensure_group_membership $AGENT agents

# SSH Credentials
install -d -o $AGENT -g $AGENT -m 700 /home/$AGENT/.ssh # idempotent
AUTHORIZED_KEYS="/home/$AGENT/.ssh/authorized_keys"
if [ ! -f "$AUTHORIZED_KEYS" ]; then
    install -o $AGENT -g $AGENT -m 600 /dev/null "$AUTHORIZED_KEYS"
fi
ensure_permissions "$AUTHORIZED_KEYS" "$AGENT" "$AGENT" 600
KEY="/home/$AGENT/.ssh/id_ed25519"
if [ ! -f "$KEY" ]; then
    echo "Generating SSH key"
    runuser -u $AGENT -- ssh-keygen -t ed25519 -f "$KEY" -C "$AGENT@$(hostname)" -N ""
fi
ensure_permissions "$KEY.pub" "$AGENT" "$AGENT" 644

# TODO: fix name, implement service file
# WARNING: agentd doesn't get new permissions until restarted
#systemctl restart agentd-manager.service 2>/dev/null

# install hermes as service

loginctl enable-linger "$AGENT"

sudo -iu "$AGENT"

curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash

mkdir -p ~/workspace	
hermes config set terminal.cwd ~/workspace

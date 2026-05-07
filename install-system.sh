#!/bin/bash
#
# prepare system for AI agents

# change system UMASK - more durable than hoping users don't change their settings
sudo sed -i 's/^\(UMASK[[:space:]]\+\)022/\1027/' /etc/login.defs

# system install of Hermes

if [ ! -x /usr/local/bin/hermes ]; then
    sudo install -d -o root -g root -m 755 /usr/local/share/uv/python
    sudo install -d -o root -g root -m 755 /usr/local/share/uv/bin

    curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh \
        sudo env \
            UV_PYTHON_INSTALL_DIR=/usr/local/share/uv/python \
            UV_PYTHON_BIN_DIR=/usr/local/share/uv/bin \
            bash -s -- --skip-setup

    sudo chown -R root:root /usr/local/lib/hermes-agent /usr/local/share/uv
    sudo chmod -R a+rX /usr/local/lib/hermes-agent /usr/local/share/uv
    sudo chmod 755 /usr/local/bin/hermes
fi

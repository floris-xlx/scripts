#!/bin/bash

set -e

# Variables
NITTER_USER="nitter"
NITTER_DIR="/home/${NITTER_USER}/nitter"
NITTER_REPO="https://github.com/zedeus/nitter"
SERVICE_FILE="/etc/systemd/system/nitter.service"

# Ensure libsass-dev is installed
sudo apt update
sudo apt install -y git nim libsass-dev

# Create nitter user if not exists
if ! id "$NITTER_USER" >/dev/null 2>&1; then
    sudo useradd -m -s /bin/bash "$NITTER_USER"
fi

# Clone the repo as the nitter user
sudo -u "$NITTER_USER" git clone "$NITTER_REPO" "$NITTER_DIR"
cd "$NITTER_DIR"

# Build the project
sudo -u "$NITTER_USER" nimble build -d:danger --mm:refc

# Run nimble commands interactively
echo "You might be prompted during these steps if dependencies are missing."
sudo -u "$NITTER_USER" nimble scss
sudo -u "$NITTER_USER" nimble md

# Copy config
sudo -u "$NITTER_USER" cp nitter.example.conf nitter.conf

# Create systemd service
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Nitter (An alternative Twitter front-end)
After=syslog.target
After=network.target

[Service]
Type=simple
User=${NITTER_USER}
Group=${NITTER_USER}
WorkingDirectory=${NITTER_DIR}
ExecStart=${NITTER_DIR}/nitter
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
EOF

# Reload and enable service
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now nitter.service

echo "Nitter has been installed and started successfully."

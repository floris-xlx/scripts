#!/bin/bash

# Usage check
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <nginx-config-filename> <new-port>"
  exit 1
fi

CONFIG_FILE="/etc/nginx/sites-available/$1"
NEW_PORT="$2"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Config file '$CONFIG_FILE' does not exist."
  exit 1
fi

# Replace port (assumes default "listen <port>" format)
echo "Updating port in $CONFIG_FILE to $NEW_PORT..."
sudo sed -i "s/listen [0-9]\+;/listen $NEW_PORT;/" "$CONFIG_FILE"

# Test nginx configuration
echo "Testing nginx configuration..."
if sudo nginx -t; then
  echo "Nginx config OK. Reloading..."
  sudo systemctl reload nginx
  sudo systemctl daemon-reexec
  echo "Done."
else
  echo "Nginx config test failed. Reverting changes..."
  sudo git checkout -- "$CONFIG_FILE" 2>/dev/null || echo "No git backup, manual revert may be needed."
  exit 1
fi


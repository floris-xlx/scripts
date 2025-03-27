#!/bin/bash

# Usage: ./update-nginx-port-full.sh <nginx-config-filename>

set -e

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <nginx-config-filename>"
  exit 1
fi

CONFIG_NAME="$1"
CONFIG_PATH="/etc/nginx/sites-available/$CONFIG_NAME"
JSON_PATH="/.xbp/xbp.json"

if [ ! -f "$CONFIG_PATH" ]; then
  echo "Nginx config '$CONFIG_PATH' not found."
  exit 1
fi

if [ ! -f "$JSON_PATH" ]; then
  echo "JSON config '$JSON_PATH' not found."
  exit 1
fi

# Extract current port from the config
CURRENT_PORT=$(grep -Eo "listen [0-9]+" "$CONFIG_PATH" | awk '{print $2}' | head -n 1)

if [ -z "$CURRENT_PORT" ]; then
  echo "Could not extract current port from $CONFIG_PATH"
  exit 1
fi

echo "Current port is: $CURRENT_PORT"

# Check if current port is in use
if sudo fuser ${CURRENT_PORT}/tcp > /dev/null 2>&1; then
  echo "Port $CURRENT_PORT is in use. Finding a new one..."

  # Find a free port
  for ((new_port=1025; new_port<=65535; new_port++)); do
    if ! sudo fuser ${new_port}/tcp > /dev/null 2>&1; then
      echo "Found available port: $new_port"
      break
    fi
  done

  if [ "$new_port" -gt 65535 ]; then
    echo "No available port found."
    exit 1
  fi

  # Update Nginx config with the new port
  sudo sed -i "s/listen ${CURRENT_PORT};/listen ${new_port};/" "$CONFIG_PATH"

  # Update JSON file
  jq ".port = $new_port" "$JSON_PATH" > /tmp/xbp.json.tmp && sudo mv /tmp/xbp.json.tmp "$JSON_PATH"

  # Test nginx config
  echo "Testing Nginx config..."
  if sudo nginx -t; then
    echo "Reloading Nginx..."
    sudo systemctl reload nginx
    sudo systemctl daemon-reexec
    echo "Port updated successfully to $new_port"
  else
    echo "Nginx config test failed. Reverting changes."
    sudo sed -i "s/listen ${new_port};/listen ${CURRENT_PORT};/" "$CONFIG_PATH"
    jq ".port = $CURRENT_PORT" "$JSON_PATH" > /tmp/xbp.json.tmp && sudo mv /tmp/xbp.json.tmp "$JSON_PATH"
    exit 1
  fi
else
  echo "Port $CURRENT_PORT is free. Nothing to update."
fi


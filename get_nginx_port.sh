#!/bin/bash

# Usage check
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <nginx-config-filename>"
  exit 1
fi

CONFIG_FILE="/etc/nginx/sites-available/$1"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Config file '$CONFIG_FILE' does not exist."
  exit 1
fi

# Extract the first port from a listen directive
PORT=$(grep -Eo "listen [0-9]+" "$CONFIG_FILE" | awk '{print $2}' | head -n 1)

if [ -n "$PORT" ]; then
  echo "$PORT"
else
  echo "No port found in $CONFIG_FILE"
  exit 1
fi


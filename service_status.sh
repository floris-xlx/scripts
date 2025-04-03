#!/bin/bash

# Check if a service is online
# Usage: ./is_service_online.sh <service_name>

SERVICE_NAME=$1

if [ -z "$SERVICE_NAME" ]; then
  echo "Usage: $0 <service_name>"
  exit 1
fi

# Check if the service exists
if ! systemctl list-units --type=service --all | grep -q "$SERVICE_NAME"; then
  echo "Service $SERVICE_NAME does not exist."
  exit 1
fi

# Check if the service is active
if systemctl is-active --quiet "$SERVICE_NAME"; then
  echo "true"
else
  echo "false"
fi

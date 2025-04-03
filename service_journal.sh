#!/bin/bash

# Dumps JournalCTL of that process
# Usage: ./service_journal.sh <service_name>

SERVICE_NAME=$1

if [ -z "$SERVICE_NAME" ]; then
  echo "Usage: $0 <service_name>"
  exit 1
fi

# Dumps journalctl logs of that service
sudo journalctl -u $SERVICE_NAME --no-pager --lines=50
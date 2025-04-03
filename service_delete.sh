#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 <service_name>"
    exit 1
}

# Check if the service name is provided
if [ -z "$1" ]; then
    echo "Error: No service name provided."
    usage
fi

SERVICE_NAME=$1
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# Check if the service exists
if [ ! -f "$SERVICE_FILE" ]; then
    echo "Service file not found: $SERVICE_FILE"
    exit 1
fi


# Disable the service
echo "Disabling the service: $SERVICE_NAME"
sudo systemctl disable "$SERVICE_NAME"

# Stop the service if it's running
echo "Stopping the service: $SERVICE_NAME"
sudo systemctl stop "$SERVICE_NAME"

# Delete the service file
if [ -f "$SERVICE_FILE" ]; then
    echo "Deleting the service file: $SERVICE_FILE"
    sudo rm "$SERVICE_FILE"
else
    echo "Service file not found: $SERVICE_FILE"
fi

# Reload systemd daemon
echo "Reloading systemd daemon"
sudo systemctl daemon-reload

echo "Service $SERVICE_NAME has been disabled and deleted."

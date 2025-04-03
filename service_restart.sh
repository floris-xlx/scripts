#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 <service_name>"
    exit 1
}

# Check if the service name is provided
if [ -z "$1" ]; then
    echo -e "\e[31mError: Missing service name.\e[0m"
    usage
fi

SERVICE_NAME=$1

# Function to reboot the service
reboot_service() {
    echo -e "\e[33mRebooting the service: $SERVICE_NAME\e[0m"
    echo "floris" | sudo -S systemctl restart "$SERVICE_NAME"
}

# Function to check the status of the service
check_service_status() {
    echo -e "\e[34mChecking the status of the service: $SERVICE_NAME\e[0m"
    echo "floris" | sudo -S systemctl is-active --quiet "$SERVICE_NAME"
    if [ $? -eq 0 ]; then
        echo -e "\e[32mService '$SERVICE_NAME' is active and running.\e[0m"
    else
        echo -e "\e[31mService '$SERVICE_NAME' is not running.\e[0m"
        echo -e "\e[31mDumping latest logs of journalctl for '$SERVICE_NAME'\e[0m"
        sudo journalctl -u $SERVICE_NAME --no-pager --lines=50
        exit 1
    fi
}

# Reboot the service
reboot_service

# Check the status of the service
check_service_status

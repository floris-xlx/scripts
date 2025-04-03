#!/bin/bash

# Usage message
usage() {
    echo "Usage: $0 --port <PORT> --protocol <udp|tcp|all>"
    exit 1
}

# Default values
PORT=""
PROTOCOL=""

# Parse CLI arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --port)
            PORT="$2"
            shift 2
            ;;
        --protocol)
            PROTOCOL="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

# Validate inputs
if [[ -z "$PORT" || -z "$PROTOCOL" ]]; then
    usage
fi

# Function to check if port is in use
check_port() {
    local port=$1
    local proto=$2

    case "$proto" in
        tcp)
            netstat -tln | awk -v p="$port" '$4 ~ ":"p"$" {exit 1}'
            ;;
        udp)
            netstat -uln | awk -v p="$port" '$4 ~ ":"p"$" {exit 1}'
            ;;
        all)
            netstat -tuln | awk -v p="$port" '$4 ~ ":"p"$" {exit 1}'
            ;;
        *)
            echo "Invalid protocol. Use 'tcp', 'udp', or 'all'."
            exit 1
            ;;
    esac

    # Return boolean status
    if [[ $? -eq 0 ]]; then
        exit 0  # Port is free
    else
        exit 1  # Port is in use
    fi
}

# Check the port and return status
check_port "$PORT" "$PROTOCOL"

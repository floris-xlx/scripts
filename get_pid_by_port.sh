#!/bin/bash

# Check if a port number was provided
if [ -z "$1" ]; then
  echo "Usage: $0 <port>"
  exit 1
fi

PORT=$1

# Get the PID using the port
PID=$(sudo fuser ${PORT}/tcp 2>/dev/null)

if [ -n "$PID" ]; then
  echo "Process using port $PORT:"
  ps -fp $PID
else
  echo "No process found on port $PORT"
fi


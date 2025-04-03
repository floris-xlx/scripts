#!/bin/bash

echo "Listing all PM2 processes..."
pm2 list --no-color || { echo "Failed to list PM2 processes."; exit 1; }

echo "Identifying stopped processes and deleting them..."
pm2 list --no-color | awk '/stopped/ {print $2}' | xargs -I {} pm2 delete {} || { echo "Failed to delete stopped processes."; exit 1; }

echo "Saving the current PM2 process list..."
pm2 save || { echo "Failed to save PM2 process list."; exit 1; }

echo "Operation completed."

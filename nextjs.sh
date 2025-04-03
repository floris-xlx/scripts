#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 --app-name <APP_NAME> --port <PORT> --app-dir <APP_DIR>"
    exit 1
}


# Parse CLI arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --app-name)
            APP_NAME="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --app-dir)
            APP_DIR="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

# Validate inputs
if [[ -z "$APP_NAME" || -z "$PORT" || -z "$APP_DIR" ]]; then
    usage
fi

# Redeploy $APP_NAME
echo "Redeploying $APP_NAME"
cd "$APP_DIR" || { echo "Failed to navigate to $APP_DIR directory"; exit 1; }

echo "Resetting local changes for $APP_NAME ..."
git reset --hard || { echo "Failed to reset local changes for $APP_NAME "; exit 1; }

echo "Pulling latest changes for $APP_NAME ..."
git pull origin main || { echo "Failed to pull latest changes for $APP_NAME "; exit 1; }

echo "Installing dependencies for $APP_NAME ..."
pnpm install || { echo "Failed to install dependencies for $APP_NAME "; exit 1; }

echo "Building $APP_NAME ..."
pnpm run build || { echo "Failed to build $APP_NAME "; exit 1; }

echo "Stopping existing PM2 process for $APP_NAME ..."
pm2 stop "$APP_NAME" || echo "No existing process found for $APP_NAME. Proceeding..."

echo "Starting $APP_NAME with PM2..."
pm2 start "pnpm run start -p $PORT" --name "$APP_NAME" -- --port $PORT || { echo "Failed to start $APP_NAME "; exit 1; }

echo "Saving PM2 process list for $APP_NAME ..."
pm2 save || { echo "Failed to save PM2 process list for $APP_NAME "; exit 1; }
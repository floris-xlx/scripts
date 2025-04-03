#!/bin/bash

# Check Nginx configuration syntax
echo "Checking Nginx configuration syntax..."
if sudo nginx -t; then
    echo "Nginx configuration syntax is valid."

    # Reload Nginx service
    echo "Reloading Nginx service..."
    sudo systemctl reload nginx

    # Reload systemd manager configuration
    echo "Reloading systemd manager configuration..."
    sudo systemctl daemon-reload

    echo "Nginx and systemd reloaded successfully."
else
    echo "Nginx configuration syntax is invalid. Please fix the errors above."
    exit 1
fi

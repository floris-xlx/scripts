#!/bin/bash

# Check if a db_id and port are provided
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <db_id> <port>"
    exit 1
fi

DB_ID=$1
PORT=$2
NGINX_CONF="/etc/nginx/sites-available/db.xylex.cloud"

# Check if the NGINX configuration file exists
if [ ! -f "$NGINX_CONF" ]; then
    echo "Error: NGINX configuration file '$NGINX_CONF' not found."
    exit 1
fi

# Store the current content of the NGINX configuration file in RAM
ORIGINAL_CONTENT=$(cat "$NGINX_CONF")

# Use awk to remove the specific if statement block matching the db_id and port
awk -v db_id="$DB_ID" -v port="$PORT" '
    BEGIN { in_block = 0 }
    /if \(\$db_id = ".*"\) {/ { 
        if ($0 ~ "if \\(\\$db_id = \"" db_id "\"\\) {") {
            in_block = 1
        }
    }
    in_block && /set \$upstream "http:\/\/127\.0\.0\.1:.*";/ {
        if ($0 ~ "set \\$upstream \"http://127\\.0\\.0\\.1:" port "\";") {
            in_block = 2
        }
    }
    in_block && /}/ {
        if (in_block == 2) {
            in_block = 0
            next
        }
    }
    !in_block
' "$NGINX_CONF" > temp && mv temp "$NGINX_CONF"

# Check if sed command was successful
if [ $? -eq 0 ]; then
    echo "Removed if statement block for db_id '$DB_ID' and port '$PORT' from $NGINX_CONF"
    
    # Call the NGINX verify API
    RESPONSE=$(curl -s -X GET https://api.xylex.cloud/nginx/config_verify)
    STATUS=$(echo "$RESPONSE" | jq -r '.status')
  

    if [ "$STATUS" == "Success" ]; then
        echo "NGINX configuration verified successfully."
    else
        echo "Error: NGINX configuration verification failed. Restoring original configuration."
        # Restore the original content of the NGINX configuration file
        cat /etc/nginx/sites-available/db.xylex.cloud
        echo "$ORIGINAL_CONTENT" > "$NGINX_CONF"
        exit 1
    fi
else
    echo "Error: Failed to remove if statement block for db_id '$DB_ID' and port '$PORT'."
    exit 1
fi
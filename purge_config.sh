#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 <service_name> <config_file_path> <database_name> <port>"
    exit 1
}

# Check if the service name, config file path, and database name are provided
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
    echo "Error: Missing arguments."
    usage
fi

SERVICE_NAME=$1
CONFIG_FILE_PATH=$2
DB_NAME=$3
PORT=$4

# Call the service_delete script to disable and delete the service
echo "Deleting the service: $SERVICE_NAME"
./scripts/service/service_delete.sh "$SERVICE_NAME"

# Delete the configuration file as user floris-xlx
if [ -f "$CONFIG_FILE_PATH" ]; then
    echo "Deleting the configuration file: $CONFIG_FILE_PATH"
    if echo "floris" | sudo -S -u floris-xlx rm "$CONFIG_FILE_PATH"; then
        echo "Configuration file deleted successfully."
    else
        echo "Error: Failed to delete configuration file: $CONFIG_FILE_PATH"

    fi
else
    echo "Configuration file not found: $CONFIG_FILE_PATH"
fi

# Call the force_drop_db script to drop the database
echo "Dropping the database: $DB_NAME"
./scripts/postgres/admin/force_drop_db.sh "$DB_NAME"


# also call the nginx remover 
#  ./scripts/nginx/remove_statement.sh $DB_NAME
echo "Purging statement out of NGINX"
./scripts/nginx/remove_statement.sh $DB_NAME $PORT
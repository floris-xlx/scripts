#!/bin/bash

# Usage message
usage() {
    echo "Usage: $0 --dbname <DB_NAME>"
    exit 1
}

DB_NAME=""

# Parse CLI arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
    --dbname)
        DB_NAME="$2"
        shift 2
        ;;
    *)
        usage
        ;;
    esac
done

if [ -z "$DB_NAME" ]; then
    usage
fi

sudo -u postgres psql -h db.xylex.cloud -p 5432 -d "$DB_NAME"

#!/bin/bash

# Directory to list files from
directory="/etc/nginx/sites-enabled"

# Initialize an empty JSON array
json_output="["

# Iterate over each file in the directory
for file in "$directory"/*; do
    # Get the base name of the file
    filename=$(basename "$file")

    # Check if the file is a symlink
    if [ -L "$file" ]; then
        # Get the target of the symlink
        target=$(readlink "$file")
        # Append the filename and symlink target to the JSON array
        json_output+="{\"filename\": \"$filename\", \"symlink\": true, \"target\": \"$target\"},"
    else
        # Append the filename to the JSON array with symlink as false
        json_output+="{\"filename\": \"$filename\", \"symlink\": false},"
    fi
done

# Remove the trailing comma and close the JSON array
json_output="${json_output%,}]"

# Output the JSON array
echo "$json_output"

#!/bin/bash

# Directory to list files from
directory="/etc/nginx/sites-available"

# Initialize an empty JSON array
json_output="["

# Iterate over each file in the directory
for file in "$directory"/*; do
    # Get the base name of the file
    filename=$(basename "$file")
    
    # Append the filename to the JSON array
    json_output+="\"$filename\","
done

# Remove the trailing comma and close the JSON array
json_output="${json_output%,}]"

# Output the JSON array
echo "$json_output"

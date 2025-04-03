#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <repository_url> <github_api_key> <folder_name>"
    exit 1
fi

repository_url=$1
github_api_key=$2
folder_name=$3

# Extract the repository name from the URL
repo_name=$(basename -s .git "$repository_url")

# Construct the URL with the API key
auth_url=$(echo "$repository_url" | sed "s|https://|https://$github_api_key@|")

# Clone the repository with depth 1 into the specified folder
git clone --depth 1 "$auth_url" "$folder_name"
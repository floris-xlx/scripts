#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if command succeeded
check_command() {
    if [ $? -eq 0 ]; then
        print_success "$1"
    else
        print_error "$2"
        exit 1
    fi
}

print_status "Starting ScyllaDB installation..."

# Download and execute ScyllaDB installation script
print_status "Downloading and executing ScyllaDB installation script..."
curl -sSf get.scylladb.com/server | sudo bash
check_command "ScyllaDB installed successfully" "Failed to install ScyllaDB"

# Verify ScyllaDB installation
if command -v scylla >/dev/null 2>&1; then
    print_success "ScyllaDB installation verified - scylla command is available"
else
    print_warning "ScyllaDB may not have installed correctly - scylla command not found"
fi

print_success "ScyllaDB installation completed successfully!"
print_status "You can now start ScyllaDB with: sudo systemctl start scylla-server"
print_status "To enable ScyllaDB to start on boot: sudo systemctl enable scylla-server"

systemctl start scylla-server
sudo systemctl enable scylla-server
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

print_status "Starting Elixir and Erlang installation..."

# Update package list
print_status "Updating package list..."
sudo apt-get update
check_command "Package list updated successfully" "Failed to update package list"

# Install prerequisites
print_status "Installing prerequisites (curl, gnupg)..."
sudo apt-get install -y curl gnupg
check_command "Prerequisites installed successfully" "Failed to install prerequisites"

# Add Erlang Solutions GPG key
print_status "Adding Erlang Solutions GPG key..."
curl -fsSL https://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc | sudo tee /etc/apt/trusted.gpg.d/erlang.gpg > /dev/null
if [ ${PIPESTATUS[0]} -eq 0 ] && [ ${PIPESTATUS[1]} -eq 0 ]; then
    print_success "Erlang Solutions GPG key added successfully"
else
    print_error "Failed to download or add Erlang Solutions GPG key"
    exit 1
fi

# Verify the GPG key was created
if [ ! -f /etc/apt/trusted.gpg.d/erlang.gpg ]; then
    print_error "GPG key file was not created properly"
    exit 1
fi

# Add Erlang Solutions repository
print_status "Adding Erlang Solutions repository..."
echo "deb https://packages.erlang-solutions.com/ubuntu $(lsb_release -cs) contrib" | sudo tee /etc/apt/sources.list.d/erlang.list > /dev/null
check_command "Erlang Solutions repository added successfully" "Failed to add Erlang Solutions repository"

# Verify the repository was added
if [ ! -f /etc/apt/sources.list.d/erlang.list ]; then
    print_error "Erlang repository file was not created"
    exit 1
fi

# Update package list again
print_status "Updating package list with new repository..."
sudo apt-get update
check_command "Package list updated successfully" "Failed to update package list"

# Install Elixir (which includes Erlang)
print_status "Installing Elixir and Erlang..."
sudo apt-get install -y elixir
check_command "Elixir and Erlang installed successfully" "Failed to install Elixir and Erlang"

# Verify installations
print_status "Verifying installations..."

if command -v elixir >/dev/null 2>&1; then
    print_success "Elixir installation verified - elixir command is available"
    elixir_version=$(elixir -v | head -1)
    print_status "Elixir version: $elixir_version"
else
    print_warning "Elixir may not have installed correctly - elixir command not found"
fi

if command -v mix >/dev/null 2>&1; then
    print_success "Mix installation verified - mix command is available"
    mix_version=$(mix -v | head -1)
    print_status "Mix version: $mix_version"
else
    print_warning "Mix may not have installed correctly - mix command not found"
fi

if command -v erl >/dev/null 2>&1; then
    print_success "Erlang installation verified - erl command is available"
else
    print_warning "Erlang may not have installed correctly - erl command not found"
fi

print_success "Elixir and Erlang installation completed successfully!"
print_status "You can now use Elixir with: elixir -v"
print_status "You can now use Mix with: mix -v"
print_status "You can start an Erlang shell with: erl"
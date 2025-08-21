#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' 


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


check_command() {
    if [ $? -eq 0 ]; then
        print_success "$1"
    else
        print_error "$2"
        exit 1
    fi
}

print_status "Starting Grafana installation..."


print_status "Installing required packages (apt-transport-https, software-properties-common, wget)..."
sudo apt-get install -y apt-transport-https software-properties-common wget
check_command "Required packages installed successfully" "Failed to install required packages"


print_status "Creating keyrings directory..."
sudo mkdir -p /etc/apt/keyrings/
check_command "Keyrings directory created successfully" "Failed to create keyrings directory"


print_status "Downloading and adding Grafana GPG key..."
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
if [ ${PIPESTATUS[0]} -eq 0 ] && [ ${PIPESTATUS[1]} -eq 0 ] && [ ${PIPESTATUS[2]} -eq 0 ]; then
    print_success "Grafana GPG key added successfully"
else
    print_error "Failed to download or add Grafana GPG key"
    exit 1
fi


if [ ! -f /etc/apt/keyrings/grafana.gpg ]; then
    print_error "GPG key file was not created properly"
    exit 1
fi

print_status "Adding Grafana repository to sources list..."
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list > /dev/null
check_command "Grafana repository added successfully" "Failed to add Grafana repository"
if [ ! -f /etc/apt/sources.list.d/grafana.list ]; then
    print_error "Grafana repository file was not created"
    exit 1
fi

# Update package list
print_status "Updating package list..."
sudo apt-get update
check_command "Package list updated successfully" "Failed to update package list"

print_status "Installing Grafana..."
sudo apt-get install -y grafana
check_command "Grafana installed successfully" "Failed to install Grafana"

if command -v grafana-server >/dev/null 2>&1; then
    print_success "Grafana installation verified - grafana-server command is available"
else
    print_warning "Grafana may not have installed correctly - grafana-server command not found"
fi

print_success "Grafana installation completed successfully!"
print_status "You can now start Grafana with: sudo systemctl start grafana-server"
print_status "To enable Grafana to start on boot: sudo systemctl enable grafana-server"

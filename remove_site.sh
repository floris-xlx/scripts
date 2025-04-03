#!/bin/bash

# Function to display a message in red color
print_red() {
    echo -e "\e[31m$1\e[0m" >&2
}

# Function to display a message in blue color
print_blue() {
    echo -e "\e[34m$1\e[0m"
}

# Function to display a message in green color
print_green() {
    echo -e "\e[32m$1\e[0m"
}

# Function to display an error message and exit
die() {
    print_red "$1"
    exit 1
}

# Check if the domain is provided
if [ -z "$1" ]; then
    die "Usage: $0 <domain>"
fi

DOMAIN="$1"

# Call certbot to delete the certificate
sudo certbot delete --cert-name "$DOMAIN" || die "Failed to delete certificate for $DOMAIN"

# Define paths
SITES_AVAILABLE="./sites-available/$DOMAIN"
SITES_ENABLED="./sites-enabled/$DOMAIN"
LETSENCRYPT_RENEWAL="/etc/letsencrypt/renewal/$DOMAIN.conf"
LETSENCRYPT_ARCHIVE="/etc/letsencrypt/archive/$DOMAIN"
LETSENCRYPT_LIVE="/etc/letsencrypt/live/$DOMAIN"

# Remove the site configuration from sites-available
if [ -f "$SITES_AVAILABLE" ]; then
    sudo rm "$SITES_AVAILABLE" || die "Failed to remove $SITES_AVAILABLE"
else
    print_blue "$SITES_AVAILABLE does not exist. Treating as success."
fi

# Remove the site configuration from sites-enabled
if [ -f "$SITES_ENABLED" ]; then
    sudo rm "$SITES_ENABLED" || die "Failed to remove $SITES_ENABLED"
else
    print_blue "$SITES_ENABLED does not exist. Treating as success."
fi

# Remove the Let's Encrypt renewal configuration
if [ -f "$LETSENCRYPT_RENEWAL" ]; then
    sudo rm "$LETSENCRYPT_RENEWAL" || die "Failed to remove $LETSENCRYPT_RENEWAL"
else
    print_blue "$LETSENCRYPT_RENEWAL does not exist. Treating as success."
fi

# Remove the Let's Encrypt renewal configuration from /etc/letsencrypt/renewal
if [ -f "/etc/letsencrypt/renewal/$DOMAIN.conf" ]; then
    sudo rm "/etc/letsencrypt/renewal/$DOMAIN.conf" || die "Failed to remove /etc/letsencrypt/renewal/$DOMAIN.conf"
else
    print_blue "/etc/letsencrypt/renewal/$DOMAIN.conf does not exist. Treating as success."
fi

# Remove the Let's Encrypt archive directory
if [ -d "$LETSENCRYPT_ARCHIVE" ]; then
    sudo rm -rf "$LETSENCRYPT_ARCHIVE" || die "Failed to remove $LETSENCRYPT_ARCHIVE"
else
    print_blue "$LETSENCRYPT_ARCHIVE does not exist. Treating as success."
fi

# Remove the Let's Encrypt live directory
if [ -d "$LETSENCRYPT_LIVE" ]; then
    sudo rm -rf "$LETSENCRYPT_LIVE" || die "Failed to remove $LETSENCRYPT_LIVE"
else
    print_blue "$LETSENCRYPT_LIVE does not exist. Treating as success."
fi

print_green "Site $DOMAIN removed successfully."

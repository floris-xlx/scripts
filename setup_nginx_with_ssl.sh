#!/bin/bash

# Function to display an error message and exit
die() {
  print_red "$1"
  exit 1
}

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

# Parse command line arguments
for arg in "$@"; do
  case $arg in
    --domain=*)
      DOMAIN="${arg#*=}"
      shift
      ;;
    --port=*)
      PORT="${arg#*=}"
      shift
      ;;
    *)
      die "Invalid argument: $arg"
      ;;
  esac
done

# Validate input
if [[ -z "$DOMAIN" || -z "$PORT" ]]; then
  die "Both --domain and --port must be provided."
fi

# Check if Nginx is installed
if ! command -v nginx >/dev/null 2>&1; then
  die "Nginx is not installed. Please install it before running this script."
fi

# Check if Certbot is installed
if ! command -v certbot >/dev/null 2>&1; then
  die "Certbot is not installed. Please install it before running this script."
fi

# Create an Nginx configuration for the domain
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
NGINX_LINK="/etc/nginx/sites-enabled/$DOMAIN"

sudo cat > "$NGINX_CONF" <<EOL
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

# Enable the site
sudo ln -s "$NGINX_CONF" "$NGINX_LINK" 2>/dev/null || true

# Test the Nginx configuration
sudo nginx -t || die "Nginx configuration test failed. Please check your configuration."

# Reload Nginx
sudo systemctl reload nginx || die "Failed to reload Nginx."

# Obtain an SSL certificate
CERTBOT_OUTPUT=$(sudo certbot --nginx -d "$DOMAIN" 2>&1)
if ! echo "$CERTBOT_OUTPUT" | grep -q "Successfully deployed certificate for $DOMAIN"; then
  die "Certbot failed to obtain the certificate."
fi

# Update the Nginx configuration for SSL
cat > "$NGINX_CONF" <<EOL
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

# Test and reload the updated Nginx configuration
nginx -t || die "Nginx configuration test failed after adding SSL."
systemctl reload nginx || die "Failed to reload Nginx after adding SSL."

# Success message
print_green "SSL certificate created and Nginx configuration updated successfully for $DOMAIN forwarding to localhost:$PORT."
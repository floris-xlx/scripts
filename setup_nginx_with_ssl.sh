#!/bin/bash
set -euo pipefail

die() {
  echo "❌ $1" >&2
  exit 1
}

DOMAIN=""
PORT=""

# Parse CLI args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    *)
      die "Unknown option: $1. Use --domain <domain> --port <port>"
      ;;
  esac
done

[[ -z "$DOMAIN" || -z "$PORT" ]] && die "Usage: $0 --domain <domain> --port <port>"

command -v nginx >/dev/null 2>&1 || die "Nginx is not installed."
command -v certbot >/dev/null 2>&1 || die "Certbot is not installed."

NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
NGINX_LINK="/etc/nginx/sites-enabled/$DOMAIN"

# Remove old config
if [[ -f "$NGINX_CONF" ]]; then
  echo "⚠️ Existing config found for $DOMAIN, overwriting..."
  sudo rm -f "$NGINX_CONF" "$NGINX_LINK"
fi


# Create HTTP-only config with webroot path
sudo mkdir -p /var/www/certbot
sudo tee "$NGINX_CONF" > /dev/null <<EOL
server {
    listen 80;
    server_name $DOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

# Enable site
sudo ln -s "$NGINX_CONF" "$NGINX_LINK"

# Test & reload Nginx
sudo nginx -t || { rm -f "$NGINX_CONF" "$NGINX_LINK"; die "Nginx test failed."; }
sudo systemctl reload nginx

# Request certificate using webroot
if ! sudo certbot certonly --webroot -w /var/www/certbot -d "$DOMAIN" --agree-tos --non-interactive -m admin@"$DOMAIN"; then
  rm -f "$NGINX_CONF" "$NGINX_LINK"
  sudo systemctl reload nginx
  die "Certbot failed to obtain certificate."
fi

# Write final HTTPS config
sudo tee "$NGINX_CONF" > /dev/null <<EOL
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
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_buffers 8 32k;
        proxy_buffer_size 64k;
        client_max_body_size 500M;
    }
}
EOL


sudo nginx -t
sudo systemctl restart nginx
sudo systemctl daemon-reload




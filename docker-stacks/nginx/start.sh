#!/bin/bash

DOMAIN="${DOMAIN:-example.com}"
EMAIL="${EMAIL:-your-email@example.com}"

# Register account with Let's Encrypt
~/.acme.sh/acme.sh --register-account -m $EMAIL

# Issue/renew certificate using Cloudflare DNS challenge
~/.acme.sh/acme.sh --issue --dns dns_cf -d $DOMAIN --force

# Install the certificate
~/.acme.sh/acme.sh --install-cert -d $DOMAIN \
    --key-file /etc/nginx/ssl/$DOMAIN.key \
    --fullchain-file /etc/nginx/ssl/$DOMAIN.crt

# Add HTTPS server block to NGINX config
cat << EOF >> /etc/nginx/nginx.conf
    server {
        listen 443 ssl;
        server_name $DOMAIN;

        ssl_certificate /etc/nginx/ssl/$DOMAIN.crt;
        ssl_certificate_key /etc/nginx/ssl/$DOMAIN.key;

        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
EOF

# Start NGINX
nginx -g 'daemon off;'
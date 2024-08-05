#!/bin/bash

DOMAIN="${DOMAIN:-example.com}"
EMAIL="${EMAIL:-your-email@example.com}"

# Register account with Let's Encrypt using the provided email (this is idempotent)
~/.acme.sh/acme.sh --register-account -m $EMAIL

# Check if the certificate exists and is still valid
if [ ! -f "/etc/nginx/ssl/$DOMAIN.crt" ] || ! openssl x509 -noout -checkend 2592000 -in "/etc/nginx/ssl/$DOMAIN.crt"; then
    echo "Certificate doesn't exist or will expire within 30 days. Issuing/renewing..."
    # Issue/renew wildcard certificate using Cloudflare DNS challenge
    ~/.acme.sh/acme.sh --issue --dns dns_cf -d "$DOMAIN" -d "*.$DOMAIN" --force

    # Install the certificate
    ~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
        --key-file /etc/nginx/ssl/$DOMAIN.key \
        --fullchain-file /etc/nginx/ssl/$DOMAIN.crt
else
    echo "Certificate is still valid. Skipping renewal."
fi

# Add HTTPS server block to NGINX config if it doesn't exist
if ! grep -q "listen 443 ssl" /etc/nginx/nginx.conf; then
    cat << EOF >> /etc/nginx/nginx.conf
    server {
        listen 443 ssl;
        server_name $DOMAIN *.$DOMAIN;

        ssl_certificate /etc/nginx/ssl/$DOMAIN.crt;
        ssl_certificate_key /etc/nginx/ssl/$DOMAIN.key;

        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
EOF
fi

# Start NGINX
nginx -g 'daemon off;'
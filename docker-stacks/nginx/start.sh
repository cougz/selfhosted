#!/bin/bash

# Check if CF_Token is set
if [ -z "$CF_Token" ]; then
    echo "Error: CF_Token is not set. Please set your Cloudflare API token."
    exit 1
fi

# Register account with Let's Encrypt (if not already registered)
~/.acme.sh/acme.sh --register-account -m "admin@example.com"

# Function to issue/renew certificate
# Function to issue/renew certificate
issue_cert() {
    local domain=$1
    echo "Issuing/renewing certificate for $domain"
    ~/.acme.sh/acme.sh --issue --dns dns_cf \
        -d "$domain" -d "*.$domain" \
        --keylength ec-384 \
        --ocsp-must-staple \
        --force
    ~/.acme.sh/acme.sh --install-cert -d "$domain" \
        --key-file /etc/nginx/ssl/$domain.key \
        --fullchain-file /etc/nginx/ssl/$domain.crt \
        --ecc
}

# Read domains from a file or environment variable
# For now, we'll use a placeholder. In practice, you might want to pass this as a file or environment variable
DOMAINS="example.com example2.com"

for domain in $DOMAINS; do
    if [ ! -f "/etc/nginx/ssl/$domain.crt" ] || ! openssl x509 -noout -checkend 2592000 -in "/etc/nginx/ssl/$domain.crt"; then
        issue_cert $domain
    else
        echo "Certificate for $domain is still valid. Skipping renewal."
    fi
done

# Ensure default nginx configuration exists
if [ ! -f "/etc/nginx/conf.d/default.conf" ]; then
    cat << EOF > /etc/nginx/conf.d/default.conf
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    server_name _;
    ssl_certificate /etc/nginx/ssl/default.crt;
    ssl_certificate_key /etc/nginx/ssl/default.key;

    # Other SSL parameters...

    location / {
        return 444;
    }
}
EOF
fi

# Start NGINX
nginx -g 'daemon off;'